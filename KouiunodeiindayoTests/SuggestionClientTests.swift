import Foundation
import Testing

@testable import Kouiunodeiindayo

/// Worker に送る形・返る形の読み書き。ネットは呼ばない。形は `docs/suggestion-api.md` が正。
@MainActor
struct SuggestionClientTests {
    private let configuration = SuggestionClient.Configuration(
        baseURL: URL(string: "https://worker.example.com")!,
        token: "test-token"
    )

    // MARK: 送るラベルの整形

    @Test func 確信度の高い順に並べて小数第2位に丸める() throws {
        let request = try #require(
            SuggestionRequest(labels: [
                ImageLabel(name: "soup", confidence: 0.123),
                ImageLabel(name: "ramen", confidence: 0.625),
                ImageLabel(name: "chopsticks", confidence: 0.0849),
            ]))
        #expect(
            request.labels == [
                .init(name: "ramen", confidence: 0.63),
                .init(name: "soup", confidence: 0.12),
                .init(name: "chopsticks", confidence: 0.08),
            ])
    }

    @Test func 最大20個まで() throws {
        let labels = (0..<30).map { ImageLabel(name: "label_\($0)", confidence: Float($0) / 100) }
        let request = try #require(SuggestionRequest(labels: labels))
        #expect(request.labels.count == 20)
        #expect(request.labels.first?.name == "label_29")
        #expect(request.labels.last?.name == "label_10")
    }

    @Test func 確信度が同じなら名前の順() throws {
        let request = try #require(
            SuggestionRequest(labels: [
                ImageLabel(name: "tea_drink", confidence: 0.3),
                ImageLabel(name: "coffee", confidence: 0.3),
            ]))
        #expect(request.labels.map(\.name) == ["coffee", "tea_drink"])
    }

    @Test(arguments: ["Ramen", "fried-chicken", "ice cream", "", "らーめん", String(repeating: "a", count: 65)])
    func 名前の形に合わないラベルは捨てる(name: String) throws {
        let request = try #require(
            SuggestionRequest(labels: [
                ImageLabel(name: name, confidence: 0.9),
                ImageLabel(name: "ramen", confidence: 0.5),
            ]))
        #expect(request.labels.map(\.name) == ["ramen"])
    }

    @Test func 名前は64文字までと数字と下線を使える() {
        #expect(SuggestionRequest.isValidName(String(repeating: "a", count: 64)))
        #expect(SuggestionRequest.isValidName("cake_regular"))
        #expect(SuggestionRequest.isValidName("7up"))
    }

    @Test func 送れるラベルが無ければnil() {
        #expect(SuggestionRequest(labels: []) == nil)
        #expect(SuggestionRequest(labels: [ImageLabel(name: "Bad-Name", confidence: 0.9)]) == nil)
    }

    @Test func 確信度は0から1に収める() {
        #expect(SuggestionRequest.rounded(1.2) == 1)
        #expect(SuggestionRequest.rounded(-0.1) == 0)
        #expect(SuggestionRequest.rounded(0.004) == 0)
    }

    // MARK: 送るリクエスト

    @Test func リクエストの宛先とヘッダーと本文() throws {
        let request = try #require(SuggestionRequest(labels: [ImageLabel(name: "ramen", confidence: 0.62)]))
        let urlRequest = try SuggestionClient.makeURLRequest(request, configuration: configuration)

        #expect(urlRequest.url?.absoluteString == "https://worker.example.com/suggest")
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

        let body = try #require(urlRequest.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let labels = try #require(json["labels"] as? [[String: Any]])
        #expect(json.keys.sorted() == ["labels"])
        #expect(labels.count == 1)
        #expect(labels.first?["name"] as? String == "ramen")
        #expect(labels.first?["confidence"] as? Double == 0.62)
    }

    @Test func URLの末尾にスラッシュがあっても宛先はひとつのsuggest() throws {
        let request = try #require(SuggestionRequest(labels: [ImageLabel(name: "ramen", confidence: 0.62)]))
        let withSlash = SuggestionClient.Configuration(baseURL: URL(string: "https://worker.example.com/")!, token: "t")
        let urlRequest = try SuggestionClient.makeURLRequest(request, configuration: withSlash)
        #expect(urlRequest.url?.absoluteString == "https://worker.example.com/suggest")
    }

    // MARK: 返る JSON

    @Test func 提案を読む() throws {
        let data = Data(#"{"genre":"food","tags":["ramen","noodles","chinese"]}"#.utf8)
        let result = try SuggestionClient.decodeResult(from: data)
        #expect(result == SuggestionResult(genre: .food, tags: [.ramen, .noodles, .chinese]))
    }

    @Test func 提案なしを読む() throws {
        let data = Data(#"{"genre":null,"tags":[]}"#.utf8)
        #expect(try SuggestionClient.decodeResult(from: data) == .empty)
    }

    @Test(arguments: ["unsorted", "none", "soup"])
    func 提案できないジャンルはnil(genre: String) throws {
        let data = Data(#"{"genre":"\#(genre)","tags":["coffee"]}"#.utf8)
        let result = try SuggestionClient.decodeResult(from: data)
        #expect(result.genre == nil)
        #expect(result.tags == [.coffee])
    }

    @Test func 知らないタグは捨てる() throws {
        let data = Data(#"{"genre":"dessert","tags":["unknown_tag","cake"]}"#.utf8)
        #expect(try SuggestionClient.decodeResult(from: data) == SuggestionResult(genre: .dessert, tags: [.cake]))
    }

    @Test func 壊れたJSONはthrowする() {
        #expect(throws: (any Error).self) {
            try SuggestionClient.decodeResult(from: Data("not json".utf8))
        }
        #expect(throws: (any Error).self) {
            try SuggestionClient.decodeResult(from: Data(#"{"genre":"food"}"#.utf8))
        }
    }

    // MARK: URL と合言葉の設定

    @Test func 設定を読む() {
        let info: [String: Any] = ["SuggestionBaseURL": " https://worker.example.com ", "SuggestionToken": "abc"]
        #expect(
            SuggestionClient.configuration(from: info)
                == .init(baseURL: URL(string: "https://worker.example.com")!, token: "abc"))
    }

    @Test(arguments: [
        ["SuggestionBaseURL": "", "SuggestionToken": "abc"],
        ["SuggestionBaseURL": "https://worker.example.com", "SuggestionToken": ""],
        ["SuggestionBaseURL": "$(SUGGESTION_BASE_URL)", "SuggestionToken": "abc"],
        ["SuggestionBaseURL": "https://worker.example.com", "SuggestionToken": "$(SUGGESTION_TOKEN)"],
        ["SuggestionBaseURL": "https:", "SuggestionToken": "abc"],
        ["SuggestionBaseURL": "ftp://worker.example.com", "SuggestionToken": "abc"],
        ["SuggestionToken": "abc"],
    ])
    func 未設定や読めない設定はnil(info: [String: String]) {
        #expect(SuggestionClient.configuration(from: info) == nil)
    }
}
