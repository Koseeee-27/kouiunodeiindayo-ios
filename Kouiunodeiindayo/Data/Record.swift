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
    // 以下はあとから足した項目。保存済みのデータをそのまま読めるよう、既定値は init ではなく宣言に書く。
    /// 付いているタグのキー（`Tag` の rawValue）。
    var tags: [String] = []
    /// 提案したジャンル（`food`／`drink`／`dessert`）。提案が無かったとき・まだ問い合わせていないときは `nil`。
    var suggestedGenre: String? = nil
    /// 提案したジャンルの確率（0〜1。Jev の probabilities）。おまかせで任せるかの判定に使う。
    /// 提案したジャンルが無い・まだ問い合わせていない・確率を返す前の Worker で問い合わせた記録は `nil`。
    var suggestedGenreConfidence: Double? = nil
    /// 提案したタグのキー。
    var suggestedTags: [String] = []
    /// 提案を問い合わせ終えた日時。提案が無かったときも入る。`nil` はまだ問い合わせていない（通信できなかったときも `nil` のまま）。
    var suggestedAt: Date? = nil

    /// `genre` を enum として読み書きするための窓口。保存されるのは文字列のまま。
    var genreValue: Genre {
        get { Genre(storedValue: genre) }
        set { genre = newValue.rawValue }
    }

    /// 付いているタグ。知らないキーは捨てる（表示しない・落とさない）。書き込みは `RecordStore.setTags` から。
    var tagValues: [Tag] {
        tags.compactMap(Tag.init(rawValue:))
    }

    /// 提案したジャンル。知らない値と、提案できないジャンル（`unsorted`・`none`）は `nil`。
    var suggestedGenreValue: Genre? {
        suggestedGenre.flatMap(Genre.init(rawValue:)).flatMap { Genre.suggestable.contains($0) ? $0 : nil }
    }

    /// 提案したタグ。知らないキーは捨てる。
    var suggestedTagValues: [Tag] {
        suggestedTags.compactMap(Tag.init(rawValue:))
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
