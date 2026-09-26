import Testing

@testable import Kouiunodeiindayo

@MainActor
struct LocalSearchParserTests {
    // `Tag` は Swift Testing の `Tag` とぶつかるので、`Kouiunodeiindayo.Tag` と書く

    @Test func 前に食べたうまいラーメン() {
        let condition = LocalSearchParser.parse("前に食べたうまいラーメン")
        #expect(condition == SearchCondition(tag: Kouiunodeiindayo.Tag.ramen, favoriteOnly: true, period: .earlier))
    }

    @Test func ひらがなでも当たる() {
        #expect(LocalSearchParser.parse("らーめん").tag == .ramen)
        #expect(LocalSearchParser.parse("からあげ").tag == .karaage)
    }

    @Test func 今週の麺() {
        let condition = LocalSearchParser.parse("今週の麺")
        #expect(condition.tag == .noodles)
        #expect(condition.period == .thisWeek)
        #expect(!condition.favoriteOnly)
    }

    @Test func 中点で分かれた名前はどちらでも当たる() {
        #expect(LocalSearchParser.parse("サラダ").tag == .vegetables)
        #expect(LocalSearchParser.parse("野菜").tag == .vegetables)
    }

    @Test func 料理と大分類を両方書いたら料理() {
        #expect(LocalSearchParser.parse("ラーメンと麺類").tag == .ramen)
    }

    @Test func おいしかったケーキ() {
        let condition = LocalSearchParser.parse("おいしかったケーキ")
        #expect(condition.tag == .cake)
        #expect(condition.favoriteOnly)
    }

    @Test func 今日は今月にならない() {
        #expect(LocalSearchParser.parse("今日").period == .today)
        #expect(LocalSearchParser.parse("今月のご飯もの").period == .thisMonth)
    }

    @Test func 読み取れない言葉は空() {
        #expect(LocalSearchParser.parse("こんにちは").isEmpty)
        #expect(LocalSearchParser.parse("").isEmpty)
    }
}
