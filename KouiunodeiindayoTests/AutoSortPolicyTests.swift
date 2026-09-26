import Foundation
import Testing

@testable import Kouiunodeiindayo

@MainActor
struct AutoSortPolicyTests {
    /// 提案つきの仕分け待ちを 1 件作る。
    private func addRecord(
        _ context: TestStore, genre: Genre? = .food, confidence: Double?
    ) throws -> Record {
        let record = try context.addRecord()
        context.store.saveSuggestion(genre: genre, genreConfidence: confidence, tags: [], for: record.id)
        return record
    }

    @Test func 境目ちょうどは任せる() throws {
        let context = TestStore()
        #expect(AutoSortPolicy.isEligible(try addRecord(context, confidence: 0.8)))
    }

    @Test func 境目より少し下は任せない() throws {
        let context = TestStore()
        #expect(!AutoSortPolicy.isEligible(try addRecord(context, confidence: 0.79)))
    }

    @Test func 確率が無ければ任せない() throws {
        let context = TestStore()
        #expect(!AutoSortPolicy.isEligible(try addRecord(context, confidence: nil)))
    }

    @Test func ジャンルが無く確率だけでも任せない() throws {
        let context = TestStore()
        let record = try addRecord(context, genre: nil, confidence: nil)
        // 保存の経路では確率だけは残らないので、直接入れて確かめる
        record.suggestedGenreConfidence = 0.95
        #expect(!AutoSortPolicy.isEligible(record))
    }

    @Test func 仕分け済みは任せない() throws {
        let context = TestStore()
        let record = try addRecord(context, confidence: 0.95)
        context.store.setGenre(.drink, for: record)
        #expect(!AutoSortPolicy.isEligible(record))
    }

    @Test func 次に任せるのは並び順で最初の任せられる写真() throws {
        let context = TestStore()
        let unsure = try addRecord(context, confidence: 0.6)
        let sure = try addRecord(context, genre: .drink, confidence: 0.9)
        let sure2 = try addRecord(context, genre: .dessert, confidence: 0.95)
        #expect(AutoSortPolicy.nextTarget(in: [unsure, sure, sure2])?.id == sure.id)
        #expect(AutoSortPolicy.eligibleCount(in: [unsure, sure, sure2]) == 2)
    }

    @Test func 全部自信なしならnil() throws {
        let context = TestStore()
        let records = [try addRecord(context, confidence: 0.6), try addRecord(context, confidence: nil)]
        #expect(AutoSortPolicy.nextTarget(in: records) == nil)
        #expect(AutoSortPolicy.eligibleCount(in: records) == 0)
    }

    // MARK: 先頭に出す

    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    @Test func 途中の写真を先頭に出しほかの順は変えない() {
        let items = [1, 2, 3, 4].map(Item.init)
        #expect(AutoSortPolicy.movingToFront(items, id: 3).map(\.id) == [3, 1, 2, 4])
    }

    @Test func 先頭にあればそのまま() {
        let items = [1, 2, 3].map(Item.init)
        #expect(AutoSortPolicy.movingToFront(items, id: 1).map(\.id) == [1, 2, 3])
    }

    @Test func idがnilか並びに無ければそのまま() {
        let items = [1, 2, 3].map(Item.init)
        #expect(AutoSortPolicy.movingToFront(items, id: nil).map(\.id) == [1, 2, 3])
        #expect(AutoSortPolicy.movingToFront(items, id: 9).map(\.id) == [1, 2, 3])
        #expect(AutoSortPolicy.movingToFront([Item](), id: 1).isEmpty)
    }

    // MARK: 飛ばし始めてよいか

    @Test func おまかせ中で先頭が頼みの写真なら飛ばす() {
        let id = UUID()
        let request = AutoFlightRequest(token: UUID(), recordID: id, direction: .up)
        #expect(AutoSortPolicy.shouldStartFlight(request, isAutoSorting: true, isCommitting: false, frontID: id))
    }

    @Test func 止めたあとに遅れて届いた頼みでは飛ばさない() {
        // 先頭がもともと頼みの写真（並べ替えが要らない）で、頼んだ直後に止めた場合
        let id = UUID()
        let request = AutoFlightRequest(token: UUID(), recordID: id, direction: .up)
        #expect(!AutoSortPolicy.shouldStartFlight(request, isAutoSorting: false, isCommitting: false, frontID: id))
    }

    @Test func 飛んでいる間・先頭が違う・頼みが無いときは飛ばさない() {
        let id = UUID()
        let request = AutoFlightRequest(token: UUID(), recordID: id, direction: .left)
        #expect(!AutoSortPolicy.shouldStartFlight(request, isAutoSorting: true, isCommitting: true, frontID: id))
        #expect(!AutoSortPolicy.shouldStartFlight(request, isAutoSorting: true, isCommitting: false, frontID: UUID()))
        #expect(!AutoSortPolicy.shouldStartFlight(nil, isAutoSorting: true, isCommitting: false, frontID: id))
    }

    @Test func 提案のジャンルから向きを引く() {
        #expect(SwipeDirection(suggestedGenre: .food) == .up)
        #expect(SwipeDirection(suggestedGenre: .drink) == .left)
        #expect(SwipeDirection(suggestedGenre: .dessert) == .right)
        #expect(SwipeDirection(suggestedGenre: .noGenre) == nil)
        #expect(SwipeDirection(suggestedGenre: .unsorted) == nil)
    }
}
