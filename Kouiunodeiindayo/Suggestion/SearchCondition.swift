/// 言葉から読み取った絞り込みの条件（機能28）。`docs/suggestion-api.md` の `/search` の返りと同じ形。
struct SearchCondition: Equatable {
    var tag: Tag?
    var favoriteOnly = false
    var period: SearchPeriod?

    /// 何も指定が無い（絞り込めない）
    var isEmpty: Bool { tag == nil && !favoriteOnly && period == nil }
}

/// 撮った時期。区切りは暦で、`docs/suggestion-api.md` の `period` の表のとおり。
enum SearchPeriod: String, CaseIterable {
    case today
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case earlier

    /// 条件を見せるときの文字（M1）
    var title: String {
        switch self {
        case .today: "今日"
        case .thisWeek: "今週"
        case .thisMonth: "今月"
        case .earlier: "今月より前"
        }
    }
}
