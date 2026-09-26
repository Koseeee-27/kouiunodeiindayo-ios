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

// 外す・付けるの切り替えが、写真ごとに分かれているか（次の写真に持ち越さない）
@MainActor
struct SortTagSelectionToggleTests {
    @Test func 写真Aで外しても写真Bは全部付いたまま() {
        let photoA = UUID()
        let photoB = UUID()
        let removed = SortTagSelection.toggled(.ramen, for: photoA, in: [:])
        #expect(removed[photoA] == [.ramen])
        #expect(removed[photoB] == nil)
        let attachedB = SortTagSelection.attached(suggested: [.ramen, .noodles], removed: removed[photoB] ?? [])
        #expect(attachedB == [.ramen, .noodles])
    }

    @Test func 外したタグを戻すとまた入る() {
        let photo = UUID()
        let removed = SortTagSelection.toggled(.ramen, for: photo, in: [:])
        let restored = SortTagSelection.toggled(.ramen, for: photo, in: removed)
        #expect(restored[photo]?.isEmpty == true)
        let attached = SortTagSelection.attached(suggested: [.ramen, .noodles], removed: restored[photo] ?? [])
        #expect(attached == [.ramen, .noodles])
    }

    @Test func 二件を違うタグで仕分けると記録ごとのタグが別々() throws {
        let context = TestStore()
        let recordA = try context.addRecord()
        let recordB = try context.addRecord()
        context.store.saveSuggestion(genre: .food, tags: [.ramen, .noodles, .chinese], for: recordA.id)
        context.store.saveSuggestion(genre: .food, tags: [.ramen, .noodles, .chinese], for: recordB.id)
        var removed = SortTagSelection.toggled(.chinese, for: recordA.id, in: [:])
        removed = SortTagSelection.toggled(.ramen, for: recordB.id, in: removed)
        SortTagSelection.commit(recordA, genre: .food, removed: removed[recordA.id] ?? [], store: context.store)
        SortTagSelection.commit(recordB, genre: .food, removed: removed[recordB.id] ?? [], store: context.store)
        #expect(recordA.tags == ["ramen", "noodles"])
        #expect(recordB.tags == ["noodles", "chinese"])
    }
}
