import Foundation
import Testing

@testable import Kouiunodeiindayo

// `Tag` は Swift Testing にも同じ名前の型があるので、アプリの `Tag` はモジュール名を付けて書く
@MainActor
struct SortTagSelectionTests {
    @Test func 外したタグは除き提案の順のまま() {
        let attached = SortTagSelection.attached(suggested: [.ramen, .noodles, .chinese], removed: [.noodles])
        #expect(attached == [.ramen, .chinese])
    }

    @Test func 外したタグは記録に入らず残りが入る() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.ramen, .noodles, .chinese], for: record.id)
        SortTagSelection.commit(record, genre: .food, removed: [.chinese], store: context.store)
        #expect(record.tags == ["ramen", "noodles"])
        #expect(record.genreValue == .food)
    }

    @Test func 全部外すとタグは空() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.ramen, .noodles], for: record.id)
        SortTagSelection.commit(record, genre: .drink, removed: [.ramen, .noodles], store: context.store)
        #expect(record.tags.isEmpty)
        #expect(record.genreValue == .drink)
    }

    @Test func 提案が届く前に進むとタグは空のまま() throws {
        let context = TestStore()
        let record = try context.addRecord()
        SortTagSelection.commit(record, genre: .dessert, removed: [], store: context.store)
        #expect(record.tags.isEmpty)
        #expect(record.genreValue == .dessert)
    }

    @Test func 次に進んでも提案のタグは変わらない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.tempura, .fried, .japanese], for: record.id)
        SortTagSelection.commit(record, genre: .food, removed: [.japanese], store: context.store)
        #expect(record.suggestedTags == ["tempura", "fried", "japanese"])
    }

    @Test func 外したタグを戻すとまた入る() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.tempura, .fried], for: record.id)
        var removed: Set<Kouiunodeiindayo.Tag> = [.fried]
        removed.remove(.fried)
        SortTagSelection.commit(record, genre: .food, removed: removed, store: context.store)
        #expect(record.tags == ["tempura", "fried"])
    }
}
