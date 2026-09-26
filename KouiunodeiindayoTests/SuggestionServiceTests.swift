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

    @Test func 問い合わせ直しを使い切ったら保存せず次に頼めば問い合わせ直す() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        // 問い合わせ直しを 0 回にして、使い切ったときの動きを見る
        let service = LiveSuggestionService(
            labels: Self.fixedLabels, suggest: probe.suggest, policy: Self.fastPolicy(retries: 0))

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

    // MARK: 問い合わせ直しと、問い合わせの間（#113）

    /// テスト用の短い決まり。本物は 2 秒・5 秒の問い合わせ直し、1 秒から倍々で上限 8 秒の間
    private static func fastPolicy(
        retries: Int = 2, backoffStart: Duration = .milliseconds(30), backoffMax: Duration = .milliseconds(120)
    ) -> LiveSuggestionService.RetryPolicy {
        LiveSuggestionService.RetryPolicy(
            retryDelays: Array(repeating: .milliseconds(5), count: retries),
            backoffStart: backoffStart,
            backoffMax: backoffMax,
            successesToRelax: 3,
            relaxFloor: .milliseconds(15)
        )
    }

    @Test func 最初が失敗しても問い合わせ直して保存する() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest, policy: Self.fastPolicy())
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { record.suggestedAt != nil }
        #expect(probe.callCount == 2)
        #expect(record.suggestedGenreValue == .food)
    }

    @Test func 三回とも失敗したら保存せず次に頼めばまた問い合わせる() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 3)
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest, policy: Self.fastPolicy())
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { probe.callCount == 3 }
        try await Task.sleep(for: .milliseconds(100))
        #expect(probe.callCount == 3)
        #expect(record.suggestedAt == nil)
        // 使い切ったあとに頼み直すと、また問い合わせる（仕分けの画面を開き直すのに当たる）
        for _ in 0..<100 where record.suggestedAt == nil {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(probe.callCount == 4)
        #expect(record.suggestedAt != nil)
    }

    @Test func Visionの失敗は問い合わせ直さず問い合わせ直しでVisionは動かし直さない() async throws {
        let context = TestStore()
        let failing = try context.addRecord()
        let retried = try context.addRecord()
        var labelCalls: [UUID: Int] = [:]
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        let service = LiveSuggestionService(
            labels: { url in
                let id = url == context.photoStorage.photoURL(fileName: failing.photoFileName) ? failing.id : retried.id
                labelCalls[id, default: 0] += 1
                if id == failing.id { throw CocoaError(.fileReadUnknown) }
                return [ImageLabel(name: "ramen", confidence: 0.9)]
            },
            suggest: probe.suggest, policy: Self.fastPolicy())
        service.requestSuggestion(for: failing.id, photoFileName: failing.photoFileName, store: context.store)
        service.requestSuggestion(for: retried.id, photoFileName: retried.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { retried.suggestedAt != nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(labelCalls[failing.id] == 1)
        #expect(failing.suggestedAt == nil)
        // retried は 1 回失敗して問い合わせ直した（Worker に 2 回）が、Vision は 1 回だけ
        #expect(probe.callCount == 2)
        #expect(labelCalls[retried.id] == 1)
    }

    @Test func 失敗が無ければ問い合わせの間を空けない() async throws {
        let context = TestStore()
        let records = try (0..<5).map { _ in try context.addRecord() }
        let probe = SuggesterProbe()
        let service = LiveSuggestionService(
            labels: Self.fixedLabels, suggest: probe.suggest, policy: Self.fastPolicy(backoffStart: .seconds(1)))
        for record in records {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        }
        try await waitUntil(tries: 500) { records.allSatisfy { $0.suggestedAt != nil } }
        #expect(service.interval == .zero)
        // 間を空けていれば 1 秒ずつかかる。続けて問い合わせていれば 5 件でも 1 秒よりずっと短い
        let first = try #require(probe.callTimes.first)
        let last = try #require(probe.callTimes.last)
        #expect(last - first < .milliseconds(500))
    }

    @Test func 失敗が続くと間を倍に広げ上限で止める() async throws {
        let context = TestStore()
        let record = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 3)
        let service = LiveSuggestionService(
            labels: Self.fixedLabels, suggest: probe.suggest,
            policy: Self.fastPolicy(backoffStart: .milliseconds(30), backoffMax: .milliseconds(50)))
        service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { probe.callCount == 3 }
        try await Task.sleep(for: .milliseconds(30))
        // 30ms → 60ms（上限 50ms で止める）→ 50ms
        #expect(service.interval == .milliseconds(50))
        let times = probe.callTimes
        try #require(times.count == 3)
        #expect(times[1] - times[0] >= .milliseconds(30))
        #expect(times[2] - times[1] >= .milliseconds(50))
    }

    @Test func 成功が続くと間を半分にしてやがて0に戻す() async throws {
        let context = TestStore()
        let records = try (0..<7).map { _ in try context.addRecord() }
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        // 失敗で 40ms。成功 3 回で 20ms、さらに 3 回で 10ms（下限 15ms を切る）になり 0
        let service = LiveSuggestionService(
            labels: Self.fixedLabels, suggest: probe.suggest,
            policy: Self.fastPolicy(backoffStart: .milliseconds(40), backoffMax: .milliseconds(40)))
        for record in records {
            service.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: context.store)
        }
        try await waitUntil(tries: 500) { records.allSatisfy { $0.suggestedAt != nil } }
        #expect(probe.callCount == 8)
        #expect(service.interval == .zero)
    }

    @Test func 問い合わせ直しを待っている間もほかの写真を先に問い合わせる() async throws {
        let context = TestStore()
        let waiting = try context.addRecord()
        let other = try context.addRecord()
        let probe = SuggesterProbe(failuresBeforeSuccess: 1)
        var policy = Self.fastPolicy(backoffStart: .milliseconds(10), backoffMax: .milliseconds(10))
        policy.retryDelays = [.seconds(1)]
        let service = LiveSuggestionService(labels: Self.fixedLabels, suggest: probe.suggest, policy: policy)
        service.requestSuggestion(for: waiting.id, photoFileName: waiting.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { probe.callCount == 1 }
        service.requestSuggestion(for: other.id, photoFileName: other.photoFileName, store: context.store)
        // 待っている写真を重ねて頼んでも弾く
        service.requestSuggestion(for: waiting.id, photoFileName: waiting.photoFileName, store: context.store)
        try await waitUntil(tries: 500) { other.suggestedAt != nil }
        #expect(waiting.suggestedAt == nil)
        try await waitUntil(tries: 500) { waiting.suggestedAt != nil }
        #expect(probe.callCount == 3)
    }

    private static let fixedLabels: LiveSuggestionService.LabelProvider = { _ in
        [ImageLabel(name: "ramen", confidence: 0.9)]
    }

    /// 条件が満たされるまで少しずつ待つ（既定で最大 1 秒）。待ち時間を見るテストは、全体を回すと遅くなるので長めに待つ
    private func waitUntil(tries: Int = 100, _ condition: () -> Bool) async throws {
        for _ in 0..<tries where !condition() {
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
    /// 呼ばれた時刻（問い合わせの間を確かめる）
    private(set) var callTimes: [ContinuousClock.Instant] = []

    init(delay: Duration = .zero, failuresBeforeSuccess: Int = 0) {
        self.delay = delay
        failuresLeft = failuresBeforeSuccess
    }

    var suggest: LiveSuggestionService.Suggester {
        { [self] _ in
            callCount += 1
            callTimes.append(.now)
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
