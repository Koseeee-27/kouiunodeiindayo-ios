/// 仕分けで付いているタグと、次に進むときの書き込み。
/// 画面は「外したタグ」だけを持ち、付いているタグは提案されたタグから外したものを除いて出す
/// （提案が後から届いても、何もしなくても全部付いた状態で出るように）。
enum SortTagSelection {
    /// 付いているタグ。提案されたタグから、外したものを除く（並びは提案の順のまま）。
    static func attached(suggested: [Tag], removed: Set<Tag>) -> [Tag] {
        suggested.filter { !removed.contains($0) }
    }

    /// ジャンルを付けて次に進むときの書き込み。スワイプでもラベルを押しても、これを呼ぶ。
    /// タグを先に書いてからジャンルを付ける（ジャンルを付けると仕分け待ちの `@Query` から消えるため）。
    static func commit(_ record: Record, genre: Genre, removed: Set<Tag>, store: RecordStore) {
        store.setTags(attached(suggested: record.suggestedTagValues, removed: removed), for: record)
        store.setGenre(genre, for: record)
    }
}
