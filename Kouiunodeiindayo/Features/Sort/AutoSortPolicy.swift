/// おまかせで任せてよい写真の決まり（機能26）。取り出し方は `docs/data-model.md` の「よく使う取り出し方」。
enum AutoSortPolicy {
    /// 任せる確率の境目。0.8 から始めて実機で調整する（#80 の計測で、Jev の正しい答えは 0.87〜1.0 に集まっていた）。
    /// 変えたら、値と理由をこのコメントと `docs/plans/auto-sort.plan.md` の「決めたこと」に書く
    static let threshold = 0.8

    /// 仕分け待ちで、提案のジャンルがあり、その確率が境目以上。
    static func isEligible(_ record: Record) -> Bool {
        guard record.genreValue == .unsorted,
            let genre = record.suggestedGenreValue,
            SwipeDirection(suggestedGenre: genre) != nil,
            let confidence = record.suggestedGenreConfidence
        else { return false }
        return confidence >= threshold
    }

    /// 任せられる写真のうち、並び順で最初のもの。無ければ nil。
    static func nextTarget(in records: [Record]) -> Record? {
        records.first(where: isEligible)
    }

    /// 任せられる写真の枚数（ボタンに添える数）。
    static func eligibleCount(in records: [Record]) -> Int {
        records.count(where: isEligible)
    }
}
