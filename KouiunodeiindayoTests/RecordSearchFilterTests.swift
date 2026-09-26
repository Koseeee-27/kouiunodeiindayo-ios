import Foundation
import Testing

@testable import Kouiunodeiindayo

@MainActor
struct RecordSearchFilterTests {
    /// 固定の「今」：2026-09-16（水）12:00（東京）。週の始まりは日曜
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.firstWeekday = 1
        return calendar
    }()
    private static let now = date(2026, 9, 16, 12)

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// 仕分け済みの記録を 1 件作る
    private func addRecord(
        _ context: TestStore, tags: [Kouiunodeiindayo.Tag] = [], favorite: Bool = false, takenAt: Date = now
    ) throws -> Record {
        let record = try context.addRecord()
        context.store.setGenre(.food, for: record)
        context.store.setTags(tags, for: record)
        if favorite { context.store.toggleFavorite(record) }
        record.takenAt = takenAt
        return record
    }

    @Test func 料理のタグは大分類と系統でも当たる() throws {
        let context = TestStore()
        let ramen = try addRecord(context, tags: [.ramen])
        #expect(RecordSearchFilter.matches(ramen, tag: .ramen))
        #expect(RecordSearchFilter.matches(ramen, tag: .noodles))
        #expect(RecordSearchFilter.matches(ramen, tag: .chinese))
        #expect(!RecordSearchFilter.matches(ramen, tag: .japanese))
    }

    @Test func 天ぷらは和食で当たり中華では当たらない() throws {
        let context = TestStore()
        let tempura = try addRecord(context, tags: [.tempura])
        #expect(RecordSearchFilter.matches(tempura, tag: .japanese))
        #expect(RecordSearchFilter.matches(tempura, tag: .fried))
        #expect(!RecordSearchFilter.matches(tempura, tag: .chinese))
    }

    @Test func うまいだけ() throws {
        let context = TestStore()
        let plain = try addRecord(context)
        let favorite = try addRecord(context, favorite: true)
        let result = RecordSearchFilter.filter([plain, favorite], by: SearchCondition(favoriteOnly: true))
        #expect(result.map(\.id) == [favorite.id])
    }

    @Test func 今日() {
        let c = Self.calendar
        #expect(RecordSearchFilter.matches(Self.date(2026, 9, 16, 0), period: .today, now: Self.now, calendar: c))
        #expect(!RecordSearchFilter.matches(Self.date(2026, 9, 15, 23), period: .today, now: Self.now, calendar: c))
    }

    @Test func 今週は週の始まり以降で未来も入る() {
        let c = Self.calendar
        // 2026-09-13（日）が週の始まり
        #expect(RecordSearchFilter.matches(Self.date(2026, 9, 13, 0), period: .thisWeek, now: Self.now, calendar: c))
        #expect(!RecordSearchFilter.matches(Self.date(2026, 9, 12, 23), period: .thisWeek, now: Self.now, calendar: c))
        #expect(RecordSearchFilter.matches(Self.date(2026, 9, 20), period: .thisWeek, now: Self.now, calendar: c))
    }

    @Test func 今月と今月より前は1日で分かれる() {
        let c = Self.calendar
        #expect(RecordSearchFilter.matches(Self.date(2026, 9, 1, 0), period: .thisMonth, now: Self.now, calendar: c))
        #expect(!RecordSearchFilter.matches(Self.date(2026, 8, 31, 23), period: .thisMonth, now: Self.now, calendar: c))
        #expect(RecordSearchFilter.matches(Self.date(2026, 8, 31, 23), period: .earlier, now: Self.now, calendar: c))
        #expect(!RecordSearchFilter.matches(Self.date(2026, 9, 1, 0), period: .earlier, now: Self.now, calendar: c))
    }

    @Test func 週の始まりが月曜なら月曜から() {
        var monday = Self.calendar
        monday.firstWeekday = 2
        // 2026-09-14（月）が週の始まり
        #expect(
            RecordSearchFilter.matches(Self.date(2026, 9, 14, 0), period: .thisWeek, now: Self.now, calendar: monday))
        #expect(
            !RecordSearchFilter.matches(Self.date(2026, 9, 13, 23), period: .thisWeek, now: Self.now, calendar: monday))
    }

    @Test func 別の時間帯でも月の境目は端末の時間帯で分かれる() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(newYork.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 1)))
        let before = try #require(
            newYork.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 23, minute: 59)))
        let start = try #require(newYork.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0)))
        #expect(RecordSearchFilter.matches(before, period: .earlier, now: now, calendar: newYork))
        #expect(!RecordSearchFilter.matches(before, period: .thisMonth, now: now, calendar: newYork))
        #expect(RecordSearchFilter.matches(start, period: .thisMonth, now: now, calendar: newYork))
    }

    @Test func 年をまたぐ週() {
        let c = Self.calendar
        // 2026-12-31（木）。週の始まりは 2026-12-27（日）
        let now = Self.date(2026, 12, 31)
        #expect(RecordSearchFilter.matches(Self.date(2026, 12, 27, 0), period: .thisWeek, now: now, calendar: c))
        #expect(!RecordSearchFilter.matches(Self.date(2026, 12, 26, 23), period: .thisWeek, now: now, calendar: c))
        #expect(RecordSearchFilter.matches(Self.date(2027, 1, 1), period: .thisWeek, now: now, calendar: c))
    }

    @Test func 知らないタグのキーだけの記録は当たらない() throws {
        let context = TestStore()
        let record = try addRecord(context)
        record.tags = ["future_tag"]
        #expect(!RecordSearchFilter.matches(record, tag: .ramen))
        #expect(RecordSearchFilter.filter([record], by: SearchCondition(tag: .ramen)).isEmpty)
    }

    @Test func 条件を組み合わせると全部を満たすものだけで並びは変えない() throws {
        let context = TestStore()
        let a = try addRecord(context, tags: [.ramen], favorite: true, takenAt: Self.date(2026, 8, 20))
        let b = try addRecord(context, tags: [.ramen], favorite: false, takenAt: Self.date(2026, 8, 10))
        let c = try addRecord(context, tags: [.gyoza], favorite: true, takenAt: Self.date(2026, 8, 5))
        let d = try addRecord(context, tags: [.ramen], favorite: true, takenAt: Self.date(2026, 9, 10))
        let e = try addRecord(context, tags: [.pasta], favorite: true, takenAt: Self.date(2026, 7, 1))
        let condition = SearchCondition(tag: .noodles, favoriteOnly: true, period: .earlier)
        let result = RecordSearchFilter.filter(
            [a, b, c, d, e], by: condition, now: Self.now, calendar: Self.calendar)
        #expect(result.map(\.id) == [a.id, e.id])
    }
}
