import Testing

@testable import Kouiunodeiindayo

@MainActor
struct TagEditingTests {
    // `Tag` は Swift Testing の `Tag` とぶつかるので、`Kouiunodeiindayo.Tag` と書く

    @Test func 付いていないタグは足される() {
        let tags: [Kouiunodeiindayo.Tag] = [.ramen]
        #expect(TagEditing.toggled(.chinese, in: tags) == [.ramen, .chinese])
    }

    @Test func 付いているタグは外れる() {
        let tags: [Kouiunodeiindayo.Tag] = [.ramen, .chinese]
        #expect(TagEditing.toggled(.ramen, in: tags) == [.chinese])
    }

    @Test func 空の一覧に足す() {
        #expect(TagEditing.toggled(.coffee, in: []) == [.coffee])
    }

    @Test func 付いていないタグを外しても変わらない() {
        let tags: [Kouiunodeiindayo.Tag] = [.ramen, .noodles]
        #expect(TagEditing.removing(.cake, from: tags) == [.ramen, .noodles])
        #expect(TagEditing.removing(.noodles, from: tags) == [.ramen])
    }

    @Test func 足した結果はタグの一覧の順で保存される() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setTags([.chinese], for: record)
        context.store.setTags(TagEditing.toggled(.gyoza, in: record.tagValues), for: record)
        #expect(record.tags == ["gyoza", "chinese"])
        context.store.setTags(TagEditing.removing(.chinese, from: record.tagValues), for: record)
        #expect(record.tags == ["gyoza"])
    }

    @Test func 知らないキーは足す・外すのあとも残る() throws {
        let context = TestStore()
        let record = try context.addRecord()
        // 新しい版のアプリが付けたタグ。このアプリの `Tag` には無い
        record.tags = ["future_tag"]
        context.store.setTags(TagEditing.toggled(.ramen, in: record.tagValues), for: record)
        #expect(record.tags == ["ramen", "future_tag"])
        context.store.setTags(TagEditing.removing(.ramen, from: record.tagValues), for: record)
        #expect(record.tags == ["future_tag"])
    }

    @Test func 料理を足しても大分類と系統は付かない() throws {
        let context = TestStore()
        let record = try context.addRecord()
        context.store.setTags(TagEditing.toggled(.ramen, in: record.tagValues), for: record)
        #expect(record.tags == ["ramen"])
    }
}
