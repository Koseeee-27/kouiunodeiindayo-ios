import Foundation
import OSLog
import SwiftUI

/// ジャンルとタグの提案（機能26）の問い合わせのまとめ役。流れは `docs/architecture.md` の「提案（機能26）の流れ」。
/// 画面は `@Environment(\.suggestionService)` で受け取り、これだけを呼ぶ（`SuggestionClient` を直接呼ばない）。
protocol SuggestionService {
    /// 写真1枚の提案を問い合わせる。すぐ戻る（結果を待たない）。結果はメインスレッドで `store.saveSuggestion` に渡す。
    /// `@Model` はスレッドをまたげないので、`Record` ではなく `id` と `photoFileName` を受け取る。
    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore)
    /// 写真の提案を待っている（待っている・問い合わせ中・問い合わせ直しの待ち）なら true。保存したら・問い合わせをやめたら false。
    /// 仕分けで「提案を待っています…」を出すのに使う（#120）。画面が変化を追えるよう、`@Observable` の値から読む
    func isPending(_ id: UUID) -> Bool
}

/// 提案を待っている写真の id の控え。画面が変化を追えるよう、これだけを `@Observable` にする
/// （Service 全体を `@Observable` にすると、待ち行列などの変化でも仕分けの画面が描き直されるため。#120）
@Observable
final class SuggestionPendingIDs {
    var ids: Set<UUID> = []
}

/// 本物。Vision（`ImageLabeler`）→ Worker（`SuggestionClient`）→ `RecordStore.saveSuggestion`。
/// 同じ写真は重ねて問い合わせず、受け付けた順に1件ずつ行う（Vision を何枚も同時に動かさない・Worker に同時に投げない）。
/// 問い合わせ中の控えをアプリ全体で1つにするため、アプリの入口で1つだけ作って渡す。
final class LiveSuggestionService: SuggestionService {
    /// 写真ファイルからラベルを取る。本物は `ImageLabeler`（Vision）。テストで差し替える
    typealias LabelProvider = (URL) async throws -> [ImageLabel]
    /// ラベルを送って提案を受け取る。本物は `SuggestionClient`（Worker）。テストで差し替える
    typealias Suggester = (SuggestionRequest) async throws -> SuggestionResult

    private struct Job {
        let id: UUID
        /// 頼まれた時点で `store` の `PhotoStorage` から作る（Service が別の置き場所で組み立てて、ずれないように）
        let photoURL: URL
        let store: RecordStore
    }

    private static let logger = Logger(category: "SuggestionService")

    private let labels: LabelProvider
    /// URL と合言葉が未設定なら `nil`。そのときは問い合わせない。
    private let suggest: Suggester?

    private var jobs: [Job] = []
    private let pending = SuggestionPendingIDs()
    /// 待っている・問い合わせ中の写真。同じ写真を重ねて頼まれたら弾く
    private var pendingIDs: Set<UUID> {
        get { pending.ids }
        set { pending.ids = newValue }
    }
    private var isRunning = false
    private var hasLoggedMissingConfiguration = false

    /// 本物。URL と合言葉は Info.plist から読む。
    convenience init(configuration: SuggestionClient.Configuration? = SuggestionClient.configurationFromBundle()) {
        let client = configuration.map { SuggestionClient(configuration: $0) }
        self.init(
            labels: { url in try await ImageLabeler.labels(ofPhotoAt: url) },
            suggest: client.map { client in { request in try await client.suggest(request) } }
        )
    }

    /// ラベルの取得と問い合わせを差し替える（テスト用。Vision もネットも呼ばずに待ち行列を確かめる）。
    init(labels: @escaping LabelProvider, suggest: Suggester?) {
        self.labels = labels
        self.suggest = suggest
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

    func isPending(_ id: UUID) -> Bool {
        pending.ids.contains(id)
    }

    private func runJobs(suggest: Suggester) async {
        while !jobs.isEmpty {
            let job = jobs.removeFirst()
            await run(job, suggest: suggest)
            // 失敗したときも外す。次に仕分けの画面を開いたときに、もう一度頼まれる
            pendingIDs.remove(job.id)
        }
        isRunning = false
    }

    /// 失敗したら何も保存しない（`suggestedAt` は `nil` のまま）。「仕分け済み・問い合わせ済みなら書かない」は `saveSuggestion` が守る。
    private func run(_ job: Job, suggest: Suggester) async {
        let labels: [ImageLabel]
        do {
            labels = try await self.labels(job.photoURL)
        } catch {
            // エラーの説明には写真のファイルの場所が入ることがあるので、種類だけを出す
            Self.logger.error("Vision でラベルを取れなかった: \(Self.describe(error), privacy: .public)")
            return
        }

        guard let request = SuggestionRequest(labels: labels) else {
            // Vision は同じ写真には同じ結果を返すので、問い合わせ直しても変わらない。提案なしとして問い合わせ済みにする
            Self.logger.info("送れるラベルが無いので、提案なしにする")
            job.store.saveSuggestion(genre: nil, tags: [], for: job.id)
            return
        }

        do {
            let result = try await suggest(request)
            // URL・合言葉・ラベルは出さない。ジャンルとその確率、タグのキーだけ
            let confidence = result.genreConfidence.map { String(format: "%.2f", $0) } ?? "-"
            Self.logger.info(
                "提案が届いた: \(result.genre?.rawValue ?? "なし", privacy: .public) \(confidence, privacy: .public) \(result.tags.map(\.rawValue).joined(separator: ","), privacy: .public)"
            )
            job.store.saveSuggestion(
                genre: result.genre, genreConfidence: result.genreConfidence, tags: result.tags, for: job.id)
        } catch {
            Self.logger.notice("提案を問い合わせられなかった: \(Self.describe(error), privacy: .public)")
        }
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
