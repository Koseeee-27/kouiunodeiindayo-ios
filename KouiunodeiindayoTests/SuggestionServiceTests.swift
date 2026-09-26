import Foundation
import Testing

@testable import Kouiunodeiindayo

/// 提案のまとめ役の、通信しない部分。Vision と Worker を呼ぶ本物の流れは実機で確かめる（`docs/plans/suggestion-app.plan.md`）。
@MainActor
struct SuggestionServiceTests {
    @Test func モックは決まった提案を保存する() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        SuggestionMock.ramen.immediate.requestSuggestion(
            for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil { record.suggestedAt != nil }
        #expect(record.suggestedGenreValue == .food)
        #expect(record.suggestedTagValues == [.ramen, .noodles, .chinese])
    }

    @Test func 提案なしのモックは問い合わせ済みにだけする() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        SuggestionMock.noSuggestion.immediate.requestSuggestion(
            for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil { record.suggestedAt != nil }
        #expect(record.suggestedGenre == nil)
        #expect(record.suggestedTags.isEmpty)
    }

    @Test func 何もしないモックは保存しない() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        SuggestionMock.disabled.requestSuggestion(
            for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await Task.sleep(for: .milliseconds(100))
        #expect(record.suggestedAt == nil)
    }

    @Test func URLと合言葉が未設定なら問い合わせない() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let service = LiveSuggestionService(configuration: nil, photoStorage: context.photoStorage)
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await Task.sleep(for: .milliseconds(100))
        #expect(record.suggestedAt == nil)
    }

    /// 条件が満たされるまで少しずつ待つ（最大 1 秒）。
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
