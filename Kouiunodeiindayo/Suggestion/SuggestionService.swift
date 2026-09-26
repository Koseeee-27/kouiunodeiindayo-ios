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
/// 問い合わせ中の控えをアプリ全体で1つにするため、アプリの入口で1つだけ作って渡す。
final class LiveSuggestionService: SuggestionService {
    private struct Job {
        let id: UUID
        let photoFileName: String
        let store: RecordStore
    }

    private static let logger = Logger(category: "SuggestionService")

    /// URL と合言葉が未設定なら `nil`。そのときは問い合わせない。
    private let client: SuggestionClient?
    private let photoStorage: PhotoStorage

    private var jobs: [Job] = []
    /// 待っている・問い合わせ中の写真。同じ写真を重ねて頼まれたら弾く
    private var pendingIDs: Set<UUID> = []
    private var isRunning = false
    private var hasLoggedMissingConfiguration = false

    init(
        configuration: SuggestionClient.Configuration? = SuggestionClient.configurationFromBundle(),
        photoStorage: PhotoStorage = .standard
    ) {
        client = configuration.map { SuggestionClient(configuration: $0) }
        self.photoStorage = photoStorage
    }

    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore) {
        guard let client else {
            if !hasLoggedMissingConfiguration {
                hasLoggedMissingConfiguration = true
                Self.logger.notice("Worker の URL か合言葉が未設定なので、提案を問い合わせない（docs/setup.md の 7）")
            }
            return
        }
        guard pendingIDs.insert(id).inserted else { return }
        jobs.append(Job(id: id, photoFileName: photoFileName, store: store))
        guard !isRunning else { return }
        isRunning = true
        Task {
            await runJobs(client: client)
        }
    }

    private func runJobs(client: SuggestionClient) async {
        while !jobs.isEmpty {
            let job = jobs.removeFirst()
            await run(job, client: client)
            // 失敗したときも外す。次に仕分けの画面を開いたときに、もう一度頼まれる
            pendingIDs.remove(job.id)
        }
        isRunning = false
    }

    /// 失敗したら何も保存しない（`suggestedAt` は `nil` のまま）。「仕分け済み・問い合わせ済みなら書かない」は `saveSuggestion` が守る。
    private func run(_ job: Job, client: SuggestionClient) async {
        let labels: [ImageLabel]
        do {
            labels = try await ImageLabeler.labels(ofPhotoAt: photoStorage.photoURL(fileName: job.photoFileName))
        } catch {
            Self.logger.error("Vision でラベルを取れなかった: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let request = SuggestionRequest(labels: labels) else {
            // Vision は同じ写真には同じ結果を返すので、問い合わせ直しても変わらない。提案なしとして問い合わせ済みにする
            Self.logger.info("送れるラベルが無いので、提案なしにする")
            job.store.saveSuggestion(genre: nil, tags: [], for: job.id)
            return
        }

        do {
            let result = try await client.suggest(request)
            // URL・合言葉・ラベルは出さない。ジャンルとタグのキーだけ
            Self.logger.info(
                "提案が届いた: \(result.genre?.rawValue ?? "なし", privacy: .public) \(result.tags.map(\.rawValue).joined(separator: ","), privacy: .public)"
            )
            job.store.saveSuggestion(genre: result.genre, tags: result.tags, for: job.id)
        } catch {
            Self.logger.notice("提案を問い合わせられなかった: \(Self.describe(error), privacy: .public)")
        }
    }

    /// ログ用の短い説明。`URLError` の説明には URL が入ることがあるので、種類とコードだけにする。
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
            "\(type(of: error))"
        }
    }
}

extension EnvironmentValues {
    /// 既定は何もしないモック。本物はアプリの入口（`KouiunodeiindayoApp`）で渡す。
    /// プレビューが本物の Worker を呼んでクレジットを使わないようにするため。
    @Entry var suggestionService: any SuggestionService = SuggestionMock.disabled
}
