import Testing

@testable import Kouiunodeiindayo

// `import Testing` にも `Tag`（テストに付ける目印の型）があるので、アプリの `Tag` は修飾して使う
private typealias AppTag = Kouiunodeiindayo.Tag

@MainActor
struct TagTests {
    @Test func キーは34個で重複しない() {
        let keys = AppTag.allCases.map(\.rawValue)
        #expect(keys.count == 34)
        #expect(Set(keys).count == keys.count)
    }

    @Test func 種類ごとの数は料理20大分類9系統5() {
        #expect(AppTag.tags(of: .dish).count == 20)
        #expect(AppTag.tags(of: .category).count == 9)
        #expect(AppTag.tags(of: .cuisine).count == 5)
    }

    @Test func 料理の大分類と系統は正しい種類を指す() {
        for tag in AppTag.tags(of: .dish) {
            #expect(tag.visionLabels.isEmpty == false, "\(tag) に Vision のラベルが無い")
            if let category = tag.category {
                #expect(category.kind == .category)
            }
            if let cuisine = tag.cuisine {
                #expect(cuisine.kind == .cuisine)
            }
        }
    }

    @Test func 料理以外は対応を持たない() {
        for tag in AppTag.allCases where tag.kind != .dish {
            #expect(tag.visionLabels.isEmpty)
            #expect(tag.category == nil)
            #expect(tag.cuisine == nil)
        }
    }

    @Test func 代表の対応が表のとおり() {
        #expect(AppTag.ramen.category == .noodles)
        #expect(AppTag.ramen.cuisine == .chinese)
        #expect(AppTag.curry.category == .riceDish)
        #expect(AppTag.curry.cuisine == nil)
        #expect(AppTag.alcohol.visionLabels.count == 7)
        #expect(AppTag.riceDish.rawValue == "rice_dish")
        #expect(AppTag.vegetables.title == "野菜・サラダ")
    }
}
