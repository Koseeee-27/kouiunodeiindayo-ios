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

    @Test func 提案のジャンルから向きを引く() {
        #expect(SwipeDirection(suggestedGenre: .food) == .up)
        #expect(SwipeDirection(suggestedGenre: .drink) == .left)
        #expect(SwipeDirection(suggestedGenre: .dessert) == .right)
        #expect(SwipeDirection(suggestedGenre: .noGenre) == nil)
        #expect(SwipeDirection(suggestedGenre: .unsorted) == nil)
    }
}
