import Foundation
import Testing

@testable import Kouiunodeiindayo

@MainActor
struct RecordTests {
    @Test func 新しい記録はタグと提案が空() throws {
        let context = TestStore()
        let record = try context.addRecord()
        #expect(record.tags.isEmpty)
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedTags.isEmpty)
        #expect(record.suggestedAt == nil)
    }

    @Test func 知らないタグのキーは捨てて読む() throws {
        let context = TestStore()
        let record = try context.addRecord()
        record.tags = ["ramen", "unknown_tag", "chinese"]
        record.suggestedTags = ["unknown_tag", "coffee"]
        #expect(record.tagValues == [.ramen, .chinese])
        #expect(record.suggestedTagValues == [.coffee])
    }

    @Test(
        arguments: [
            ("unknown_genre", nil),
            ("", nil),
            ("unsorted", nil),
            ("none", nil),
            ("food", Genre.food),
        ] as [(String, Genre?)])
    func 提案のジャンルは提案できる値だけを読む(stored: String, expected: Genre?) throws {
        let context = TestStore()
        let record = try context.addRecord()
        record.suggestedGenre = stored
        #expect(record.suggestedGenreValue == expected)
    }
}
