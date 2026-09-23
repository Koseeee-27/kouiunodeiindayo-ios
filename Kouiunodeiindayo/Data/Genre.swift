/// 記録のジャンル。保存する文字列は `docs/data-model.md` の「ジャンルの値」が正。
enum Genre: String, CaseIterable {
    case unsorted
    case food
    case drink
    case dessert
    // `Genre?` に対する `.none` は Swift では「値が無い」と解釈され、比較が黙って外れる。
    // そのため保存する文字列は "none" のまま、case 名だけ変えている。
    case noGenre = "none"

    /// 知らない文字列は仕分け待ちに倒す。optional にすると画面ごとに nil の扱いがぶれるため。
    init(storedValue: String) {
        self = Genre(rawValue: storedValue) ?? .unsorted
    }

    /// 画面に出す名前。仕分けのラベルと、詳細での付け直しで使う。
    var title: String {
        switch self {
        case .unsorted: "仕分け待ち"
        case .food: "食べ物"
        case .drink: "飲み物"
        case .dessert: "デザート"
        case .noGenre: "なし"
        }
    }

    /// SF Symbols の名前（仮。デザインが決まったら差し替える）。
    var systemImage: String {
        switch self {
        case .unsorted: "tray"
        case .food: "fork.knife"
        case .drink: "cup.and.saucer"
        case .dessert: "birthday.cake"
        case .noGenre: "minus.circle"
        }
    }
}
