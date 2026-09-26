import Foundation
import Testing

@testable import Kouiunodeiindayo

@MainActor
struct RecordStoreTagsTests {
    // MARK: タグを変える

    @Test func タグを書くと重複を除き一覧の順に並ぶ() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setTags([.chinese, .ramen, .noodles, .ramen], for: record)
        #expect(record.tags == ["ramen", "noodles", "chinese"])
    }

    @Test func 空を渡すとタグが空になる() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setTags([.coffee], for: record)
        context.store.setTags([], for: record)
        #expect(record.tags.isEmpty)
    }

    @Test func タグを変えても提案のタグは変わらない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.ramen], for: record.id)
        context.store.setTags([.coffee], for: record)
        #expect(record.suggestedTags == ["ramen"])
    }

    // MARK: 提案を保存する

    @Test func 仕分け待ちには提案が入り付いているタグは変わらない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setTags([.coffee], for: record)
        let date = Date(timeIntervalSince1970: 1_000)
        context.store.saveSuggestion(genre: .food, tags: [.chinese, .ramen, .ramen], for: record.id, at: date)
        #expect(record.suggestedGenre == "food")
        #expect(record.suggestedTags == ["ramen", "chinese"])
        #expect(record.suggestedAt == date)
        #expect(record.tags == ["coffee"])
    }

    @Test func 仕分け済みの記録には何も書かない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setGenre(.drink, for: record)
        context.store.saveSuggestion(genre: .food, tags: [.ramen], for: record.id)
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedTags.isEmpty)
        #expect(record.suggestedAt == nil)
    }

    @Test func 消えた記録の提案は無視しほかの記録も変えない() throws {
        let context = TestStore()
        let removed = try context.addRecord()
        let kept = try context.addRecord()
        let removedID = removed.id
        try context.store.delete(removed)
        context.store.saveSuggestion(genre: .food, tags: [.ramen], for: removedID)
        let records = try context.allRecords()
        #expect(records.count == 1)
        #expect(kept.suggestedAt == nil)
        #expect(kept.suggestedGenre == nil)
    }

    @Test func 提案なしでも問い合わせ済みになる() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: nil, tags: [], for: record.id)
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedTags.isEmpty)
        #expect(record.suggestedAt != nil)
    }

    @Test func 二回目に届いた提案は無視する() throws {
        let context = TestStore()
        let record = try context.addRecord()
        let first = Date(timeIntervalSince1970: 1_000)
        context.store.saveSuggestion(genre: .food, tags: [.ramen], for: record.id, at: first)
        context.store.saveSuggestion(genre: .drink, tags: [.coffee], for: record.id, at: first.addingTimeInterval(1))
        #expect(record.suggestedGenre == "food")
        #expect(record.suggestedTags == ["ramen"])
        #expect(record.suggestedAt == first)
    }

    // MARK: ジャンルの確率

    @Test func ジャンルの確率も保存する() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, genreConfidence: 0.93, tags: [.ramen], for: record.id)
        #expect(record.suggestedGenreConfidence == 0.93)
    }

    @Test func 提案できないジャンルなら確率も書かない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .noGenre, genreConfidence: 0.9, tags: [], for: record.id)
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedGenreConfidence == nil)
    }

    @Test func 問い合わせ済みなら確率も書き換えない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, genreConfidence: 0.95, tags: [], for: record.id)
        context.store.saveSuggestion(genre: .drink, genreConfidence: 0.5, tags: [], for: record.id)
        #expect(record.suggestedGenre == "food")
        #expect(record.suggestedGenreConfidence == 0.95)
    }

    @Test(arguments: [Genre.unsorted, .noGenre])
    func 提案できないジャンルは提案なしとして書く(genre: Genre) throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: genre, tags: [.ramen], for: record.id)
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedTags == ["ramen"])
        #expect(record.suggestedAt != nil)
    }
}
