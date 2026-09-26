import Foundation

/// 仕分けで付いているタグと、次に進むときの書き込み。
/// 画面は「外したタグ」だけを持ち、付いているタグは提案されたタグから外したものを除いて出す
/// （提案が後から届いても、何もしなくても全部付いた状態で出るように）。
enum SortTagSelection {
    /// 付いているタグ。提案されたタグから、外したものを除く（並びは提案の順のまま）。
    static func attached(suggested: [Tag], removed: Set<Tag>) -> [Tag] {
        suggested.filter { !removed.contains($0) }
    }

    /// チップを押したとき。`id` の写真の外したタグで、`tag` を外す／付けるを切り替えた辞書を返す。ほかの写真の分は変えない。
    /// `id` の分がまだ無いときは `initial`（プレビューで外した状態を見るための初期値。ふつうは空）から始める。
    static func toggled(
        _ tag: Tag, for id: UUID, in removedTags: [UUID: Set<Tag>], initial: Set<Tag> = []
    ) -> [UUID: Set<Tag>] {
        var result = removedTags
        var removed = removedTags[id] ?? initial
        if removed.contains(tag) {
            removed.remove(tag)
        } else {
            removed.insert(tag)
        }
        result[id] = removed
        return result
    }

    /// ジャンルを付けて次に進むときの書き込み。スワイプでもラベルを押しても、これを呼ぶ。
    /// タグを先に書いてからジャンルを付ける（ジャンルを付けると仕分け待ちの `@Query` から消えるため）。
    static func commit(_ record: Record, genre: Genre, removed: Set<Tag>, store: RecordStore) {
        store.setTags(attached(suggested: record.suggestedTagValues, removed: removed), for: record)
        store.setGenre(genre, for: record)
    }
}
