import Foundation

/// `POST /suggest` に送る JSON。形は `docs/suggestion-api.md` が正。
nonisolated struct SuggestionRequest: Encodable, Equatable {
    nonisolated struct Label: Encodable, Equatable {
        let name: String
        let confidence: Double
    }

    /// 送るラベルの最大の数。
    static let maxLabels = 20
    /// ラベルの名前の長さの上限。
    static let maxNameLength = 64

    let labels: [Label]

    /// Vision のラベルを送る形に整える。名前の形（英小文字・数字・`_`、1〜64 文字）に合うものだけを、
    /// 確信度の高い順に最大 20 個、確信度は小数第2位に丸める。確信度が同じなら名前の順（毎回同じ結果にするため）。
    /// 1個も残らなければ `nil`（送れる形にならない）。
    init?(labels: [ImageLabel]) {
        let picked =
            labels
            .filter { Self.isValidName($0.name) }
            .sorted { $0.confidence != $1.confidence ? $0.confidence > $1.confidence : $0.name < $1.name }
            .prefix(Self.maxLabels)
            .map { Label(name: $0.name, confidence: Self.rounded($0.confidence)) }
        guard !picked.isEmpty else { return nil }
        self.labels = picked
    }

    /// 英小文字・数字・`_` だけで、1〜64 文字。Worker もこの形でないラベルを捨てる（`server/src/suggest.ts`）。
    static func isValidName(_ name: String) -> Bool {
        guard (1...maxNameLength).contains(name.utf8.count) else { return false }
        return name.utf8.allSatisfy { byte in
            (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || byte == UInt8(ascii: "_")
        }
    }

    /// 小数第2位に丸める（0.625 → 0.63）。0〜1 の外に出ないよう揃える。
    static func rounded(_ confidence: Float) -> Double {
        let value = (Double(confidence) * 100).rounded() / 100
        return min(max(value, 0), 1)
    }
}

/// `POST /suggest` から返る提案。知らないジャンル・タグのキーは捨ててある。
struct SuggestionResult: Equatable {
    /// 提案するジャンル（食べ物・飲み物・デザートのどれか）。提案しないときは `nil`。
    let genre: Genre?
    /// ジャンルの確率（0〜1）。ジャンルが無い・古い Worker で項目が無い・範囲の外なら `nil`。おまかせの判定に使う
    let genreConfidence: Double?
    let tags: [Tag]

    init(genre: Genre?, genreConfidence: Double? = nil, tags: [Tag]) {
        self.genre = genre
        self.genreConfidence = genreConfidence
        self.tags = tags
    }

    /// 提案なし（Worker が自信が低いと返したとき）。
    static let empty = SuggestionResult(genre: nil, tags: [])
}

enum SuggestionClientError: Error {
    /// HTTP の返事でなかった。
    case invalidResponse
    /// 200 以外が返った。
    case httpStatus(Int)
}

/// Worker（中継サーバー）への通信。画面からは呼ばず、`SuggestionService` から使う。
/// URL と合言葉は Info.plist（元は `Config/Local.xcconfig`。`docs/setup.md` の 7）から読む。ログにも出さない。
struct SuggestionClient {
    struct Configuration: Equatable {
        let baseURL: URL
        let token: String
    }

    /// Info.plist のキー（`Config/Info.plist`）。
    static let baseURLKey = "SuggestionBaseURL"
    static let tokenKey = "SuggestionToken"

    /// `/suggest` の時間切れ（`docs/suggestion-api.md`）。
    static let timeout: TimeInterval = 1.5

    /// 1.5 秒で打ち切る通信。`URLRequest.timeoutInterval` は「無通信の時間」なので、全体の時間（Resource）にも同じ値を入れる。
    /// キャッシュ・Cookie を端末に残さないよう ephemeral にする。
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration, session: URLSession = SuggestionClient.session) {
        self.configuration = configuration
        self.session = session
    }

    /// Info.plist から URL と合言葉を読む。未設定なら `nil`（そのときは問い合わせない）。
    static func configurationFromBundle(_ bundle: Bundle = .main) -> Configuration? {
        configuration(from: bundle.infoDictionary ?? [:])
    }

    /// どちらかが空・`$(…)` のまま（置き換わっていない）・URL として読めないときは `nil`。
    /// 合言葉を平文で流さないよう https だけにする。http は手元の `wrangler dev`（localhost）を呼ぶときだけ許す。
    static func configuration(from info: [String: Any]) -> Configuration? {
        guard let urlString = trimmedValue(info[baseURLKey]),
            let token = trimmedValue(info[tokenKey]),
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            let host = url.host()?.lowercased(),
            scheme == "https" || (scheme == "http" && host == "localhost")
        else { return nil }
        return Configuration(baseURL: url, token: token)
    }

    private static func trimmedValue(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !string.isEmpty,
            !string.contains("$(")
        else { return nil }
        return string
    }

    /// 提案を問い合わせる。200 以外・時間切れ・通信できない・JSON が読めない、はどれも throw する（どれも同じ「失敗」）。
    func suggest(_ request: SuggestionRequest) async throws -> SuggestionResult {
        let urlRequest = try Self.makeURLRequest(request, configuration: configuration)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw SuggestionClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw SuggestionClientError.httpStatus(http.statusCode)
        }
        return try Self.decodeResult(from: data)
    }

    /// 送る `URLRequest` を組み立てる。
    static func makeURLRequest(_ request: SuggestionRequest, configuration: Configuration) throws -> URLRequest {
        var urlRequest = URLRequest(url: configuration.baseURL.appending(path: "suggest"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return urlRequest
    }

    /// 返ってきた JSON を読む。知らないジャンル（提案できない `unsorted`・`none` を含む）は `nil`、知らないタグは捨てる。
    /// ジャンルの確率は、ジャンルが読めたときだけ、かつ 0〜1 のときだけ残す（それ以外は `nil`。落とさない）。
    static func decodeResult(from data: Data) throws -> SuggestionResult {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let genre = response.genre.flatMap(Genre.init(rawValue:)).flatMap { Genre.suggestable.contains($0) ? $0 : nil }
        let confidence = genre == nil ? nil : response.genreConfidence.flatMap { (0...1).contains($0) ? $0 : nil }
        return SuggestionResult(
            genre: genre, genreConfidence: confidence, tags: response.tags.compactMap(Tag.init(rawValue:)))
    }

    /// 返る JSON そのままの形。`genreConfidence` は古い Worker では無い。
    private nonisolated struct Response: Decodable {
        let genre: String?
        let genreConfidence: Double?
        let tags: [String]
    }
}

// MARK: 言葉で探す（`POST /search`。機能28）

/// `POST /search` に送る JSON。形は `docs/suggestion-api.md` が正。
nonisolated struct SearchRequest: Encodable, Equatable {
    let query: String
}

extension SuggestionClient {
    /// `/search` の時間切れ（`docs/suggestion-api.md`）。
    static let searchTimeout: TimeInterval = 3

    /// 3 秒で打ち切る通信。`/suggest` の `session` と同じく ephemeral で、全体の時間（Resource）にも同じ値を入れる。
    static let searchSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = searchTimeout
        configuration.timeoutIntervalForResource = searchTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// 検索の言葉から条件を読み取ってもらう。200 以外・時間切れ・通信できない・JSON が読めない、はどれも throw する。
    /// 言葉はログに出さない（ADR 0006）。
    func search(_ query: String, session: URLSession = SuggestionClient.searchSession) async throws -> SearchCondition {
        let urlRequest = try Self.makeSearchURLRequest(query, configuration: configuration)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw SuggestionClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw SuggestionClientError.httpStatus(http.statusCode)
        }
        return try Self.decodeSearchCondition(from: data)
    }

    /// 送る `URLRequest` を組み立てる。
    static func makeSearchURLRequest(_ query: String, configuration: Configuration) throws -> URLRequest {
        var urlRequest = URLRequest(url: configuration.baseURL.appending(path: "search"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(SearchRequest(query: query))
        return urlRequest
    }

    /// 返ってきた JSON を読む。知らないタグ・知らない時期は指定なし（`nil`）にする（落とさない）。
    static func decodeSearchCondition(from data: Data) throws -> SearchCondition {
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return SearchCondition(
            tag: response.tag.flatMap(Tag.init(rawValue:)),
            favoriteOnly: response.favoriteOnly,
            period: response.period.flatMap(SearchPeriod.init(rawValue:))
        )
    }

    /// 返る JSON そのままの形。
    private nonisolated struct SearchResponse: Decodable {
        let tag: String?
        let favoriteOnly: Bool
        let period: String?
    }
}
