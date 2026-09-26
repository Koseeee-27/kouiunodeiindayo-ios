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

    @Test func 今月を付けないより前と以前は今月より前にならない() {
        #expect(LocalSearchParser.parse("昨日以前").isEmpty)
        #expect(LocalSearchParser.parse("今日より前").period != .earlier)
        #expect(LocalSearchParser.parse("今週より前").period != .earlier)
    }

    @Test func 今月より前と以前は今月にならない() {
        #expect(LocalSearchParser.parse("今月より前のうまいもの").period == .earlier)
        #expect(LocalSearchParser.parse("今月以前").period == .earlier)
        #expect(LocalSearchParser.parse("昔のラーメン").period == .earlier)
    }

    @Test func 今年を読む() {
        let condition = LocalSearchParser.parse("今年のラーメン")
        #expect(condition == SearchCondition(tag: Kouiunodeiindayo.Tag.ramen, period: .thisYear))
        #expect(LocalSearchParser.parse("ことしのうまいもの").period == nil)
    }

    @Test func 呼び名でも当たる() {
        #expect(LocalSearchParser.parse("すし").tag == .sushi)
        #expect(LocalSearchParser.parse("ビール").tag == .alcohol)
        #expect(LocalSearchParser.parse("酒").tag == .alcohol)
    }

    @Test func 料理が2つ当たったらタグの一覧の順で先のもの() {
        // 「アイスコーヒー」は「アイス」と「コーヒー」の両方に当たる。一覧の順（コーヒーが先）で 1 つ
        #expect(LocalSearchParser.parse("アイスコーヒー").tag == .coffee)
    }

    @Test func カタカナのウマイでも当たる() {
        #expect(LocalSearchParser.parse("ウマイ").favoriteOnly)
    }

    @Test func 読み取れない言葉は空() {
        #expect(LocalSearchParser.parse("こんにちは").isEmpty)
        #expect(LocalSearchParser.parse("").isEmpty)
    }
}
