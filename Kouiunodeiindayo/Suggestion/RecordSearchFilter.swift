import Foundation

/// 言葉で探すときの絞り込み（機能28）。一覧の `@Query`（仕分け済み・新しい順）の結果を、Swift 側で絞る
/// （`tags` の配列を `#Predicate` で使うと実行時に失敗する報告があるため。`docs/data-model.md` の「言葉で探す」）。
enum RecordSearchFilter {
    /// 条件を全部満たす記録だけ。並びは変えない
    static func filter(
        _ records: [Record], by condition: SearchCondition, now: Date = .now, calendar: Calendar = .current
    ) -> [Record] {
        records.filter { record in
            if let tag = condition.tag, !matches(record, tag: tag) { return false }
            if condition.favoriteOnly, !record.isFavorite { return false }
            if let period = condition.period, !matches(record.takenAt, period: period, now: now, calendar: calendar) {
                return false
            }
            return true
        }
    }

    /// 記録にそのタグが当たるか。料理のタグは、その料理の大分類・系統にも当てはめる（「ラーメン」だけの記録も「麺類」「中華」で当たる）
    static func matches(_ record: Record, tag: Tag) -> Bool {
        record.tagValues.contains { $0 == tag || $0.category == tag || $0.cuisine == tag }
    }

    /// 撮った日がその時期に入るか。区切りは暦（週の始まりは端末の設定）。
    /// 今週・今月は「始まり以降」で見るので、日付を未来に直した記録（機能13）も入る
    static func matches(_ date: Date, period: SearchPeriod, now: Date, calendar: Calendar) -> Bool {
        switch period {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .thisWeek:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return false }
            return date >= start
        case .thisMonth:
            guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return false }
            return date >= start
        case .earlier:
            guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return false }
            return date < start
        }
    }
}
