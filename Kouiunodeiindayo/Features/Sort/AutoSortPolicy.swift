import Foundation

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

    /// `id` の写真を先頭に出した並び（おまかせで次に飛ばす写真を先頭に出す）。`id` が nil・並びに無いときはそのまま。
    /// ほかの写真の順は変えない
    static func movingToFront<Item: Identifiable>(_ items: [Item], id: Item.ID?) -> [Item] {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return items }
        var reordered = items
        reordered.insert(reordered.remove(at: index), at: 0)
        return reordered
    }

    /// 届いた飛ばす頼みで、今飛ばし始めてよいか。止めたあと・時間切れのあとに遅れて届いた頼み（おまかせ中でない）、
    /// 別の写真を飛ばしている間、先頭が頼みの写真でないときは飛ばさない（止めたら次からは飛ばさない約束を守る）
    static func shouldStartFlight(
        _ request: AutoFlightRequest?, isAutoSorting: Bool, isCommitting: Bool, frontID: UUID?
    ) -> Bool {
        guard let request, isAutoSorting, !isCommitting else { return false }
        return request.recordID == frontID
    }

    /// 任せられる写真の枚数（ボタンに添える数）。
    static func eligibleCount(in records: [Record]) -> Int {
        records.count(where: isEligible)
    }
}
