import Foundation
import OSLog
import SwiftData
import UIKit

/// 記録を書き換える唯一の入口。画面から `modelContext.insert` / `delete` やファイル書き込みを直接呼ばない。
/// 保存の仕方（ファイル名の付け方、サムネイルの作り忘れ、消し忘れ）が画面ごとにずれないようにするため。
/// 読むときは各画面が `@Query` を使う（`docs/architecture.md`）。
struct RecordStore {
    private static let logger = Logger(category: "RecordStore")

    private let modelContext: ModelContext
    private let photoStorage: PhotoStorage

    init(modelContext: ModelContext, photoStorage: PhotoStorage) {
        self.modelContext = modelContext
        self.photoStorage = photoStorage
    }

    /// 撮った写真を保存し、仕分け待ちの記録を作る。
    @discardableResult
    func add(image: UIImage, takenAt: Date) throws -> Record {
        let id = UUID()
        let photoFileName = try photoStorage.savePhotos(image, id: id)
        let record = Record(id: id, takenAt: takenAt, photoFileName: photoFileName)
        do {
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            // 記録が残らないのに写真だけ残る（孤児ファイル）のを防ぐ
            Self.logger.error("記録を保存できなかった: \(error.localizedDescription, privacy: .public)")
            modelContext.delete(record)
            deletePhotos(id: id, photoFileName: photoFileName)
            throw error
        }
        return record
    }

    /// 仕分けのスワイプ、ラベルのタップ、詳細での付け直しが、どれもこれを呼ぶ。
    func setGenre(_ genre: Genre, for record: Record) {
        record.genreValue = genre
    }

    /// 「タグを変える」。仕分けで次に進むときと、詳細での付け外しが呼ぶ。
    /// 重複を除き、タグの一覧の順に並べ直して書く（付け外しした順で並びがぶれないように）。`suggestedTags` には触らない。
    /// 今の `tags` にある知らないキー（新しい版のアプリが付けたタグなど）は、消さずにうしろに残す
    /// （`docs/data-model.md` の「知らないキーは表示しない（落とさない）」。画面は `tagValues` で知らないキーを除いて渡してくるため）。
    func setTags(_ tags: [Tag], for record: Record) {
        var seen = Set<String>()
        let unknownKeys = record.tags.filter { Tag(rawValue: $0) == nil && seen.insert($0).inserted }
        record.tags = Self.normalized(tags) + unknownKeys
    }

    /// 「提案を保存する」。裏の問い合わせの結果を、メインスレッドで `id` から記録を取り直して書く。
    /// 次のときは何も書かない：記録を取れない・消えていた／もう仕分け済み／もう問い合わせ済み（先に届いたほうを使う。
    /// 仕分けの画面でタグを外している最中に、提案が差し替わって外した状態が戻らないように）。
    /// 提案なし（`nil`・空）でも `suggestedAt` は書く。`tags` には触らない。
    func saveSuggestion(genre: Genre?, tags: [Tag], for id: UUID, at date: Date = .now) {
        var descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let record: Record
        do {
            guard let found = try modelContext.fetch(descriptor).first else {
                Self.logger.info("提案が届いたが、記録が消えていた")
                return
            }
            record = found
        } catch {
            Self.logger.error("提案を保存する記録を取れなかった: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard record.genreValue == .unsorted, record.suggestedAt == nil else { return }

        // 提案するジャンルは食べ物・飲み物・デザートだけ。それ以外は提案なしとして書く
        record.suggestedGenre = genre.flatMap { Genre.suggestable.contains($0) ? $0.rawValue : nil }
        record.suggestedTags = Self.normalized(tags)
        record.suggestedAt = date
    }

    /// 写真ファイルの場所。この `RecordStore` が使う `PhotoStorage` で組み立てる。
    /// 提案の問い合わせ（`SuggestionService`）が Vision に渡すのに使う（保存した場所と、読む場所がずれないように）。
    func photoURL(fileName: String) -> URL {
        photoStorage.photoURL(fileName: fileName)
    }

    /// 「うまい」の付け外し。
    func toggleFavorite(_ record: Record) {
        record.isFavorite.toggle()
    }

    func setTakenAt(_ takenAt: Date, for record: Record) {
        record.takenAt = takenAt
    }

    /// 記録と、写真・サムネイルのファイルを消す。
    func delete(_ record: Record) throws {
        // 記録を消したあとでは読めないので、先に控える
        let id = record.id
        let photoFileName = record.photoFileName
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            // 削除が「予定」のまま残ると、あとの自動保存で記録だけ消えて写真ファイルが残る。削除を取り消してから投げ直す
            Self.logger.error("記録を消せなかった: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            throw error
        }
        deletePhotos(id: id, photoFileName: photoFileName)
    }

    /// すべての記録と、写真・サムネイルのファイルを消す。
    func deleteAll() throws {
        // `modelContext.delete(model:)` はバッチ削除で `@Query` の画面が更新されないので、1 件ずつ消す
        let records = try modelContext.fetch(FetchDescriptor<Record>())
        for record in records {
            try delete(record)
        }
    }

    /// 重複を除き、タグの一覧（`Tag.allCases`）の順に並べたキー。
    private static func normalized(_ tags: [Tag]) -> [String] {
        let set = Set(tags)
        return Tag.allCases.filter(set.contains).map(\.rawValue)
    }

    /// ファイルの削除に失敗しても記録の削除は戻さない。孤児ファイルが残るだけなので、ログに残す。
    private func deletePhotos(id: UUID, photoFileName: String) {
        do {
            try photoStorage.deletePhotos(id: id, fileName: photoFileName)
        } catch {
            Self.logger.error(
                "写真ファイルを消せなかった: \(photoFileName, privacy: .public) \(error.localizedDescription, privacy: .public)")
        }
    }
}
