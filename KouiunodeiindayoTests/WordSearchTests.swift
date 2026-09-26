import Foundation
import Testing

@testable import Kouiunodeiindayo

/// 言葉で探す（機能28）の `POST /search` の読み書きと、Worker に聞く口。ネットは呼ばない。形は `docs/suggestion-api.md` が正。
@MainActor
struct WordSearchTests {
    // `Tag` は Swift Testing の `Tag` とぶつかるので、`Kouiunodeiindayo.Tag` と書く
    private let configuration = SuggestionClient.Configuration(
        baseURL: URL(string: "https://worker.example.com")!,
        token: "test-token"
    )

    @Test func 宛先とヘッダーと本文() throws {
        let urlRequest = try SuggestionClient.makeSearchURLRequest("こってりしたもの", configuration: configuration)
        #expect(urlRequest.url == URL(string: "https://worker.example.com/search"))
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        let body = try #require(urlRequest.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["query": "こってりしたもの"])
    }

    @Test func 条件を読む() throws {
        let data = Data(#"{"tag":"ramen","favoriteOnly":true,"period":"earlier"}"#.utf8)
        #expect(
            try SuggestionClient.decodeSearchCondition(from: data)
                == SearchCondition(tag: Kouiunodeiindayo.Tag.ramen, favoriteOnly: true, period: .earlier))
    }

    @Test func 全部指定なしを読む() throws {
        let data = Data(#"{"tag":null,"favoriteOnly":false,"period":null}"#.utf8)
        #expect(try SuggestionClient.decodeSearchCondition(from: data).isEmpty)
    }

    /// `this_year` は M1（未マージ）でアプリに入る。それまでは、知らない時期として指定なしになる
    @Test func 知らないタグと知らない時期は指定なし() throws {
        let data = Data(#"{"tag":"udon","favoriteOnly":true,"period":"last_decade"}"#.utf8)
        #expect(try SuggestionClient.decodeSearchCondition(from: data) == SearchCondition(favoriteOnly: true))
    }

    @Test(arguments: [#"{"tag":"ramen"}"#, "not json", #"{"tag":"ramen","favoriteOnly":"yes","period":null}"#])
    func 形が違えばthrow(json: String) {
        #expect(throws: (any Error).self) {
            try SuggestionClient.decodeSearchCondition(from: Data(json.utf8))
        }
    }

    @Test func URLと合言葉が未設定なら聞かずにthrow() async {
        let service = LiveWordSearchService(configuration: nil)
        await #expect(throws: WordSearchError.self) {
            try await service.search("こってりしたもの")
        }
    }

    @Test func モックは決まった条件を返し通信できないモックはthrow() async throws {
        #expect(try await WordSearchMock.ramen.search("何でも") == SearchCondition(tag: .ramen, favoriteOnly: true))
        await #expect(throws: WordSearchError.self) {
            try await WordSearchMock.disabled.search("何でも")
        }
    }
}
