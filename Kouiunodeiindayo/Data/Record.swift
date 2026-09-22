import Foundation
import SwiftData

/// 撮った写真 1 枚ぶんの記録。項目の意味は `docs/data-model.md` が正。
@Model
final class Record {
    @Attribute(.unique) var id: UUID
    var takenAt: Date
    var createdAt: Date
    /// 写真のファイル名だけを持つ。アプリの置き場所は変わることがあるので、フルパスは保存しない。
    var photoFileName: String
    var genre: String
    var isFavorite: Bool

    /// `genre` を enum として読み書きするための窓口。保存されるのは文字列のまま。
    var genreValue: Genre {
        get { Genre(storedValue: genre) }
        set { genre = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        takenAt: Date = .now,
        createdAt: Date = .now,
        photoFileName: String,
        genre: Genre = .unsorted,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.takenAt = takenAt
        self.createdAt = createdAt
        self.photoFileName = photoFileName
        self.genre = genre.rawValue
        self.isFavorite = isFavorite
    }
}
