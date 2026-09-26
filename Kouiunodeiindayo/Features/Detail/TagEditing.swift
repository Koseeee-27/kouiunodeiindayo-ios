/// 記録の詳細・タグの一覧での、タグの付け外しの計算（機能27）。書き込みは `RecordStore.setTags` が行う。
/// 並びは気にしない（`setTags` が重複を除き、`Tag.allCases` の順に並べ直す）。
enum TagEditing {
    /// `tag` が付いていれば外し、無ければ足した一覧。
    static func toggled(_ tag: Tag, in tags: [Tag]) -> [Tag] {
        tags.contains(tag) ? removing(tag, from: tags) : tags + [tag]
    }

    /// `tag` を外した一覧。付いていなければそのまま。
    static func removing(_ tag: Tag, from tags: [Tag]) -> [Tag] {
        tags.filter { $0 != tag }
    }
}
