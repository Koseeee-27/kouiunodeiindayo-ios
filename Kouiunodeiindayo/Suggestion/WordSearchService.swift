import Foundation
import SwiftUI

/// 言葉で探す（機能28）で、端末の中で読み取れなかった言葉を Worker に聞く口。
/// 画面から `SuggestionClient` を直接呼ばないよう、`@Environment(\.wordSearchService)` で受け取る（`docs/architecture.md`）。
/// 提案（`SuggestionService`）とは待ち行列も問い合わせ直しも持たないので、別の口にしている。
protocol WordSearchService {
    /// 言葉から条件を読み取ってもらう。通信できない・Worker が失敗した・URL と合言葉が未設定、はどれも throw する。
    func search(_ query: String) async throws -> SearchCondition
}

enum WordSearchError: Error {
    /// Worker の URL か合言葉が未設定（`Config/Local.xcconfig`。`docs/setup.md` の 7）
    case unavailable
}

/// 本物。`SuggestionClient` の `/search` を呼ぶ。問い合わせ直しはしない（失敗したら画面が通信できない旨を出す）。
struct LiveWordSearchService: WordSearchService {
    private let client: SuggestionClient?

    /// URL と合言葉は Info.plist から読む。未設定なら、聞くたびに `unavailable` を throw する。
    init(configuration: SuggestionClient.Configuration? = SuggestionClient.configurationFromBundle()) {
        client = configuration.map { SuggestionClient(configuration: $0) }
    }

    func search(_ query: String) async throws -> SearchCondition {
        guard let client else { throw WordSearchError.unavailable }
        return try await client.search(query)
    }
}

/// 通信せずに、決まった条件を返すモック。プレビューで使う。
struct WordSearchMock: WordSearchService {
    /// 返す条件。`nil` は通信できないのと同じ（throw する）。
    let result: SearchCondition?
    /// 問い合わせ中の見た目を見るための待ち時間。
    var delay: Duration = .zero

    /// 通信できない。`@Environment` の既定値。
    static let disabled = WordSearchMock(result: nil)
    /// 「こってりしたもの」を、うまいラーメンと読んだことにする。
    static let ramen = WordSearchMock(result: SearchCondition(tag: .ramen, favoriteOnly: true))
    /// Worker も読み取れなかった（全部指定なし）。
    static let nothing = WordSearchMock(result: SearchCondition())

    func search(_ query: String) async throws -> SearchCondition {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        guard let result else { throw WordSearchError.unavailable }
        return result
    }
}

extension EnvironmentValues {
    /// 既定は通信できないモック。本物はアプリの入口（`KouiunodeiindayoApp`）で渡す。
    @Entry var wordSearchService: any WordSearchService = WordSearchMock.disabled
}

/// 言葉で探すときの、画面が決めることの判定（テストのために画面から出す）
enum WordSearchFlow {
    /// Worker が受け付ける言葉の長さの上限（`server/src/search.ts` の `MAX_QUERY`。コードポイントで数える）
    static let maxQueryLength = 100

    static let tooLongMessage = "言葉が長すぎます。100 文字までで探してください"
    static let unreadableMessage = "条件を読み取れませんでした。タグの名前や『うまい』『今月』で探せます"
    static let offlineMessage = "通信できませんでした。タグの名前や『うまい』『今月』なら通信なしで探せます"

    /// Worker に送る前に、長すぎないかを確かめる（送っても 400 になり、通信できない旨が出てしまうため）
    static func isTooLong(_ query: String) -> Bool {
        query.unicodeScalars.count > maxQueryLength
    }

    /// 届いた結果を出してよいか。聞いている間に欄を書き換えていたら、古い語の結果は出さない
    static func shouldApply(searchedQuery: String, currentText: String) -> Bool {
        searchedQuery == currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Worker の答え（`nil` は通信できなかった）から、出す条件と知らせを決める。
    /// 読み取れない・通信できないときは、それまでの絞り込み（`previous`）を残して知らせだけ出す（一覧はそのまま）
    static func outcome(result: SearchCondition?, previous: SearchCondition?) -> (
        condition: SearchCondition?, message: String?
    ) {
        guard let result else { return (previous, offlineMessage) }
        return result.isEmpty ? (previous, unreadableMessage) : (result, nil)
    }
}
