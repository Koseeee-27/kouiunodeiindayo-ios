import Foundation
import OSLog
import SwiftUI

/// ジャンルとタグの提案（機能26）の問い合わせのまとめ役。流れは `docs/architecture.md` の「提案（機能26）の流れ」。
/// 画面は `@Environment(\.suggestionService)` で受け取り、これだけを呼ぶ（`SuggestionClient` を直接呼ばない）。
protocol SuggestionService {
    /// 写真1枚の提案を問い合わせる。すぐ戻る（結果を待たない）。結果はメインスレッドで `store.saveSuggestion` に渡す。
    /// `@Model` はスレッドをまたげないので、`Record` ではなく `id` と `photoFileName` を受け取る。
    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore)
}

/// 本物。Vision（`ImageLabeler`）→ Worker（`SuggestionClient`）→ `RecordStore.saveSuggestion`。
/// 同じ写真は重ねて問い合わせず、受け付けた順に1件ずつ行う（Vision を何枚も同時に動かさない・Worker に同時に投げない）。
/// Worker への問い合わせが失敗したら、少し待って問い合わせ直す（`RetryPolicy`）。ふだんは間を空けずに続けて問い合わせ、
/// 失敗が来たときだけ問い合わせの間を広げ、成功が続いたら戻す（Worker の回数の制限に合わせるため。`docs/plans/suggestion-retry.plan.md`）。
/// 問い合わせ中の控えをアプリ全体で1つにするため、アプリの入口で1つだけ作って渡す。
final class LiveSuggestionService: SuggestionService {
    /// 写真ファイルからラベルを取る。本物は `ImageLabeler`（Vision）。テストで差し替える
    typealias LabelProvider = (URL) async throws -> [ImageLabel]
    /// ラベルを送って提案を受け取る。本物は `SuggestionClient`（Worker）。テストで差し替える
    typealias Suggester = (SuggestionRequest) async throws -> SuggestionResult

    /// 問い合わせ直しと、問い合わせの間の決まり。テストでは短い値に差し替える
    struct RetryPolicy {
        /// 問い合わせ直すまでの待ち。要素の数が問い合わせ直しの回数
        var retryDelays: [Duration] = [.seconds(2), .seconds(5)]
        /// 失敗したときに広げる、問い合わせの間。最初の失敗でこの値、続けて失敗するたびに倍
        var backoffStart: Duration = .seconds(1)
        /// 問い合わせの間の上限
        var backoffMax: Duration = .seconds(8)
        /// 成功がこの回数続くたびに、間を半分にする
        var successesToRelax = 3
        /// 半分にしてこれを切ったら 0（ふだんの速さ）に戻す
        var relaxFloor: Duration = .milliseconds(500)
    }

    private struct Job {
        let id: UUID
        /// 頼まれた時点で `store` の `PhotoStorage` から作る（Service が別の置き場所で組み立てて、ずれないように）
        let photoURL: URL
        let store: RecordStore
        /// 最初に Vision で作った問い合わせ。問い合わせ直しで Vision を動かし直さないために持つ
        var request: SuggestionRequest?
        /// 問い合わせ直した回数
        var attempt = 0
        /// これより前には問い合わせない（問い合わせ直しの待ち）
        var notBefore: ContinuousClock.Instant?
    }

    /// 1 件を問い合わせた結果
    private enum Outcome {
        /// 保存した・問い合わせ直さない（Vision の失敗・送れるラベルが無いときも含む）
        case finished
        /// Worker への問い合わせが失敗した
        case workerFailed
    }

    private static let logger = Logger(category: "SuggestionService")

    private let labels: LabelProvider
    /// URL と合言葉が未設定なら `nil`。そのときは問い合わせない。
    private let suggest: Suggester?
    private let policy: RetryPolicy

    private var jobs: [Job] = []
    /// 待っている・問い合わせ中・問い合わせ直しを待っている写真。同じ写真を重ねて頼まれたら弾く
    private var pendingIDs: Set<UUID> = []
    private var isRunning = false
    private var hasLoggedMissingConfiguration = false
    /// 今の問い合わせの間。ふだんは 0。失敗したら広げ、成功が続いたら戻す（テストで読む）
    private(set) var interval: Duration = .zero
    private var successStreak = 0
    private var lastCallAt: ContinuousClock.Instant?

    /// 本物。URL と合言葉は Info.plist から読む。
    convenience init(configuration: SuggestionClient.Configuration? = SuggestionClient.configurationFromBundle()) {
        let client = configuration.map { SuggestionClient(configuration: $0) }
        self.init(
            labels: { url in try await ImageLabeler.labels(ofPhotoAt: url) },
            suggest: client.map { client in { request in try await client.suggest(request) } }
        )
    }

    /// ラベルの取得と問い合わせを差し替える（テスト用。Vision もネットも呼ばずに待ち行列を確かめる）。
    init(labels: @escaping LabelProvider, suggest: Suggester?, policy: RetryPolicy = RetryPolicy()) {
        self.labels = labels
        self.suggest = suggest
        self.policy = policy
    }

    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore) {
        guard let suggest else {
            if !hasLoggedMissingConfiguration {
                hasLoggedMissingConfiguration = true
                Self.logger.notice("Worker の URL か合言葉が未設定なので、提案を問い合わせない（docs/setup.md の 7）")
            }
            return
        }
        guard pendingIDs.insert(id).inserted else { return }
        jobs.append(Job(id: id, photoURL: store.photoURL(fileName: photoFileName), store: store))
        guard !isRunning else { return }
        isRunning = true
        Task {
            await runJobs(suggest: suggest)
        }
    }

    /// 問い合わせ直しを待っている写真があるとき、新しく頼まれた写真を見落とさないよう、この間隔で見直す
    private static let pollInterval: Duration = .milliseconds(50)

    private func runJobs(suggest: Suggester) async {
        while !jobs.isEmpty {
            // 待ち時間が来ている写真のうち、先頭のもの。問い合わせ直しを待っている写真は後回しにする
            let now = ContinuousClock.now
            guard let index = jobs.firstIndex(where: { ($0.notBefore ?? now) <= now }) else {
                let earliest = jobs.compactMap(\.notBefore).min() ?? now
                try? await Task.sleep(until: min(earliest, now + Self.pollInterval), clock: .continuous)
                continue
            }
            var job = jobs.remove(at: index)
            // 失敗のあとは、前の問い合わせから `interval` あける
            if interval > .zero, let lastCallAt, lastCallAt + interval > .now {
                try? await Task.sleep(until: lastCallAt + interval, clock: .continuous)
            }
            switch await run(&job, suggest: suggest) {
            case .finished:
                pendingIDs.remove(job.id)
            case .workerFailed:
                if job.attempt < policy.retryDelays.count {
                    job.notBefore = .now + policy.retryDelays[job.attempt]
                    job.attempt += 1
                    jobs.append(job)
                } else {
                    // 使い切ったら何も保存しない。次に仕分けの画面を開いたときに、もう一度頼まれる
                    pendingIDs.remove(job.id)
                }
            }
        }
        isRunning = false
    }

    /// 失敗したら何も保存しない（`suggestedAt` は `nil` のまま）。「仕分け済み・問い合わせ済みなら書かない」は `saveSuggestion` が守る。
    private func run(_ job: inout Job, suggest: Suggester) async -> Outcome {
        let request: SuggestionRequest
        if let made = job.request {
            request = made
        } else {
            let labels: [ImageLabel]
            do {
                labels = try await self.labels(job.photoURL)
            } catch {
                // エラーの説明には写真のファイルの場所が入ることがあるので、種類だけを出す。問い合わせ直さない
                Self.logger.error("Vision でラベルを取れなかった: \(Self.describe(error), privacy: .public)")
                return .finished
            }
            guard let made = SuggestionRequest(labels: labels) else {
                // Vision は同じ写真には同じ結果を返すので、問い合わせ直しても変わらない。提案なしとして問い合わせ済みにする
                Self.logger.info("送れるラベルが無いので、提案なしにする")
                job.store.saveSuggestion(genre: nil, tags: [], for: job.id)
                return .finished
            }
            job.request = made
            request = made
        }

        lastCallAt = .now
        do {
            let result = try await suggest(request)
            // URL・合言葉・ラベルは出さない。ジャンルとその確率、タグのキーだけ
            let confidence = result.genreConfidence.map { String(format: "%.2f", $0) } ?? "-"
            Self.logger.info(
                "提案が届いた: \(result.genre?.rawValue ?? "なし", privacy: .public) \(confidence, privacy: .public) \(result.tags.map(\.rawValue).joined(separator: ","), privacy: .public)"
            )
            job.store.saveSuggestion(
                genre: result.genre, genreConfidence: result.genreConfidence, tags: result.tags, for: job.id)
            relaxAfterSuccess()
            return .finished
        } catch {
            let attempt = job.attempt + 1
            Self.logger.notice(
                "提案を問い合わせられなかった（\(attempt) 回目）: \(Self.describe(error), privacy: .public)")
            widenAfterFailure()
            return .workerFailed
        }
    }

    /// 失敗したら、問い合わせの間を広げる（最初は `backoffStart`、続けて失敗するたびに倍、上限 `backoffMax`）
    private func widenAfterFailure() {
        successStreak = 0
        let widened = interval == .zero ? policy.backoffStart : min(interval * 2, policy.backoffMax)
        if widened != interval {
            interval = widened
            Self.logger.notice("問い合わせの間を \(Self.seconds(self.interval), privacy: .public) 秒にした")
        }
    }

    /// 成功が続いたら、問い合わせの間を半分にする。`relaxFloor` を切ったら 0（ふだんの速さ）に戻す
    private func relaxAfterSuccess() {
        guard interval > .zero else { return }
        successStreak += 1
        guard successStreak >= policy.successesToRelax else { return }
        successStreak = 0
        let halved = interval / 2
        interval = halved < policy.relaxFloor ? .zero : halved
        Self.logger.info("問い合わせの間を \(Self.seconds(self.interval), privacy: .public) 秒にした")
    }

    private static func seconds(_ duration: Duration) -> String {
        let components = duration.components
        return String(format: "%.1f", Double(components.seconds) + Double(components.attoseconds) / 1e18)
    }

    /// ログ用の短い説明。エラーの説明文には URL（Worker の URL・写真のファイルの場所）が入ることがあるので、種類とコードだけにする。
    private static func describe(_ error: Error) -> String {
        switch error {
        case SuggestionClientError.httpStatus(let status):
            "HTTP \(status)"
        case SuggestionClientError.invalidResponse:
            "HTTP の返事でない"
        case let urlError as URLError:
            urlError.code == .timedOut ? "時間切れ" : "通信できない（URLError \(urlError.code.rawValue)）"
        case is DecodingError:
            "返事の JSON が読めない"
        default:
            "\(type(of: error)) \((error as NSError).code)"
        }
    }
}

extension EnvironmentValues {
    /// 既定は何もしないモック。本物はアプリの入口（`KouiunodeiindayoApp`）で渡す。
    /// プレビューが本物の Worker を呼んでクレジットを使わないようにするため。
    @Entry var suggestionService: any SuggestionService = SuggestionMock.disabled
}
