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
        let service = LiveSuggestionService(configuration: nil)
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await Task.sleep(for: .milliseconds(100))
        #expect(record.suggestedAt == nil)
    }

    // MARK: 本物の待ち行列（Vision とネットは差し替える）

    @Test func 同じ写真を重ねて頼んでも問い合わせは1回() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe()
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest)

        for _ in 0..<3 {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        }
        try await waitUntil { record.suggestedAt != nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.callCount == 1)
        #expect(record.suggestedTagValues == [.ramen])
    }

    @Test func 問い合わせは1件ずつ順に行う() async throws {
        let context = TestStore()
        let records = try (0..<3).map { _ in try context.addRecord() }
        let probe = SuggesterProbe(delay: .milliseconds(30))
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest)

        for record in records {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        }
        try await waitUntil { records.allSatisfy { $0.suggestedAt != nil } }
        #expect(probe.callCount == 3)
        #expect(probe.maxConcurrent == 1)
    }

    @Test func 失敗したら保存せず次に頼めば問い合わせ直す() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest)

        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil { probe.callCount == 1 }
        #expect(record.suggestedAt == nil)

        // 失敗の後始末（控えから外す）が済むまでは弾かれるので、届くまで頼み直す（仕分けの画面を開き直すのに当たる）
        for _ in 0..<100 where record.suggestedAt == nil {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(probe.callCount == 2)
        #expect(record.suggestedGenreValue == .food)
    }

    @Test func 頼んだ写真は保存するまで待っているになる() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(delay: .milliseconds(30))
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest)
        #expect(!service.isPending(record.id))

        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        #expect(service.isPending(record.id))
        try await waitUntil { record.suggestedAt != nil }
        try await waitUntil { !service.isPending(record.id) }
    }

    @Test func 問い合わせをやめたら待っているでなくなる() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 10)
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest)

        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        #expect(service.isPending(record.id))
        try await waitUntil { !service.isPending(record.id) }
        #expect(record.suggestedAt == nil)
    }

    @Test func モックは届くまで待っているになり待ち続けるモックはずっと待っている() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let mock = SuggestionMock.ramen
        mock.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        #expect(mock.isPending(record.id))
        try await waitUntil { record.suggestedAt != nil }
        #expect(!mock.isPending(record.id))
        #expect(!SuggestionMock.disabled.isPending(record.id))
        #expect(SuggestionMock.waiting.isPending(record.id))
    }

    @Test func 写真の場所は頼んだRecordStoreの置き場所から作る() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        var receivedURL: URL?
        let service = LiveSuggestionService(
            labels: { url in
                receivedURL = url
                return [ImageLabel(name: "ramen", confidence: 0.9)]
            },
            suggest: SuggesterProbe().suggest
        )

        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil { record.suggestedAt != nil }
        #expect(receivedURL == context.photoStorage.photoURL(fileName: record.photoFileName))
    }

    @Test func 届いたジャンルの確率を記録に保存する() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: SuggesterProbe().suggest)
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil { record.suggestedAt != nil }
        #expect(record.suggestedGenreConfidence == 0.88)
    }

    private static let fixedLabels: LiveSuggestionService.LabelProvider = { _ in
        [ImageLabel(name: "ramen", confidence: 0.9)]
    }

    /// 条件が満たされるまで少しずつ待つ（最大 1 秒）。
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}

/// 差し替えた問い合わせ。呼ばれた回数と、同時に動いていた数の最大を控える。
@MainActor
private final class SuggesterProbe {
    private let delay: Duration
    private var failuresLeft: Int
    private var running = 0
    private(set) var callCount = 0
    private(set) var maxConcurrent = 0

    init(delay: Duration = .zero, failuresBeforeSuccess: Int = 0) {
        self.delay = delay
        failuresLeft = failuresBeforeSuccess
    }

    var suggest: LiveSuggestionService.Suggester {
        { [self] _ in
            callCount += 1
            running += 1
            maxConcurrent = max(maxConcurrent, running)
            defer { running -= 1 }
            if delay > .zero {
                try await Task.sleep(for: delay)
            }
            if failuresLeft > 0 {
                failuresLeft -= 1
                throw URLError(.notConnectedToInternet)
            }
            return SuggestionResult(genre: .food, genreConfidence: 0.88, tags: [.ramen])
        }
    }
}
