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
