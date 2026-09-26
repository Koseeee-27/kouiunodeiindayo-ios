import Foundation

/// 言葉の中から、タグの名前・「うまい」・時期の言葉を探して条件にする（機能28）。通信しない。
/// ひらがな・カタカナの揺れは、両方をカタカナにそろえてから比べる（「らーめん」も「ラーメン」に当たる）。
enum LocalSearchParser {
    static func parse(_ text: String) -> SearchCondition {
        let normalized = normalize(text)
        return SearchCondition(
            tag: tag(in: normalized),
            favoriteOnly: favoriteWords.contains { normalized.contains(normalize($0)) },
            period: period(in: normalized)
        )
    }

    /// タグの名前のほかに当てる呼び名。これ以上は Worker（Jev）に任せる
    static let aliases: [Tag: [String]] = [
        .ramen: ["らーめん"],
        .karaage: ["からあげ", "から揚げ"],
        .sushi: ["すし", "鮨"],
        .gyoza: ["ぎょうざ"],
        .iceCream: ["アイスクリーム"],
        .alcohol: ["ビール", "ワイン", "酒"],
        .noodles: ["麺"],
        .chinese: ["中華料理"],
    ]

    /// 「うまい」の記録だけにする言葉。「おいしかった」も当たるよう、言い切りの形ではなく頭の部分で探す
    static let favoriteWords = ["うまい", "うまかった", "美味", "旨", "おいし", "お気に入り"]

    /// 時期の言葉。上から順に探す（「今日」を含む文が「今月」などに取り違えられないように、言葉ごとに探す）。
    /// 「今月より前」「今月以前」は「今月」より先に見る（このアプリが時期の名前に使う言葉なので、そのまま打たれやすい）。
    /// 「より前」「以前」だけでは見ない（「昨日以前」「今週より前」は今月より前ではないため）
    static let periodWords: [(SearchPeriod, [String])] = [
        (.earlier, ["今月より前", "今月以前"]),
        (.today, ["今日"]),
        (.thisWeek, ["今週"]),
        (.thisMonth, ["今月"]),
        (.earlier, ["前に", "前の", "昔"]),
    ]

    /// 言葉に入っているタグ。複数当たったら料理を優先し、その中で `Tag.allCases` の順で最初の 1 つ
    /// （`/search` の返りも 1 つだけのため。「ラーメンと麺類」は「ラーメン」）
    private static func tag(in normalized: String) -> Tag? {
        let hits = Tag.allCases.filter { tag in
            names(of: tag).contains { normalized.contains(normalize($0)) }
        }
        return hits.first { $0.kind == .dish } ?? hits.first
    }

    /// タグを探す名前。「野菜・サラダ」のように「・」があるものは分けて、どちらでも当たるようにする
    private static func names(of tag: Tag) -> [String] {
        tag.title.split(separator: "・").map(String.init) + (aliases[tag] ?? [])
    }

    private static func period(in normalized: String) -> SearchPeriod? {
        periodWords.first { _, words in
            words.contains { normalized.contains(normalize($0)) }
        }?.0
    }

    /// 比べる前にそろえる：小文字にし、ひらがなをカタカナにする
    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        return lowered.applyingTransform(.hiraganaToKatakana, reverse: false) ?? lowered
    }
}
