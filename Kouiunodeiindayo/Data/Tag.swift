/// タグの種類。`docs/requirements.md` の「タグの一覧」の3種類。
enum TagKind: CaseIterable {
    case dish
    case category
    case cuisine

    /// 画面に出す種類の名前。
    var title: String {
        switch self {
        case .dish: "料理"
        case .category: "大分類"
        case .cuisine: "系統"
        }
    }
}

/// 記録に付けるタグ。保存するキーと対応表は `docs/data-model.md` の「タグの値」が正。
/// 料理の表は `server/src/tags.ts` の `DISH_TAGS` と同じ内容に保つ（片方を変えたら、もう片方と data-model.md も直す）。
/// case の並びは「タグの一覧」の順（料理 → 大分類 → 系統）。画面の並び順にもこれを使う。
enum Tag: String, CaseIterable {
    // 料理
    case ramen
    case pasta
    case sushi
    case curry
    case gyoza
    case tempura
    case karaage
    case pizza
    case hamburger
    case steak
    case sandwich
    case coffee
    case tea
    case alcohol
    case juice
    case bubbleTea = "bubble_tea"
    case cake
    case iceCream = "ice_cream"
    case donut
    case bakedSweets = "baked_sweets"

    // 大分類
    case noodles
    case riceDish = "rice_dish"
    case bread
    case meat
    case seafood
    case fried
    case egg
    case vegetables
    case soup

    // 系統
    case japanese
    case western
    case chinese
    case korean
    case ethnic

    /// 画面に出す名前。
    var title: String {
        switch self {
        case .ramen: "ラーメン"
        case .pasta: "パスタ"
        case .sushi: "寿司"
        case .curry: "カレー"
        case .gyoza: "餃子"
        case .tempura: "天ぷら"
        case .karaage: "唐揚げ"
        case .pizza: "ピザ"
        case .hamburger: "ハンバーガー"
        case .steak: "ステーキ"
        case .sandwich: "サンドイッチ"
        case .coffee: "コーヒー"
        case .tea: "お茶"
        case .alcohol: "お酒"
        case .juice: "ジュース"
        case .bubbleTea: "タピオカ"
        case .cake: "ケーキ"
        case .iceCream: "アイス"
        case .donut: "ドーナツ"
        case .bakedSweets: "焼き菓子"
        case .noodles: "麺類"
        case .riceDish: "ご飯もの"
        case .bread: "パン"
        case .meat: "肉料理"
        case .seafood: "魚介"
        case .fried: "揚げ物"
        case .egg: "卵料理"
        case .vegetables: "野菜・サラダ"
        case .soup: "汁物"
        case .japanese: "和食"
        case .western: "洋食"
        case .chinese: "中華"
        case .korean: "韓国"
        case .ethnic: "エスニック"
        }
    }

    var kind: TagKind {
        switch self {
        case .ramen, .pasta, .sushi, .curry, .gyoza, .tempura, .karaage, .pizza, .hamburger, .steak, .sandwich,
            .coffee, .tea, .alcohol, .juice, .bubbleTea, .cake, .iceCream, .donut, .bakedSweets:
            .dish
        case .noodles, .riceDish, .bread, .meat, .seafood, .fried, .egg, .vegetables, .soup:
            .category
        case .japanese, .western, .chinese, .korean, .ethnic:
            .cuisine
        }
    }

    /// 料理のタグを提案するきっかけになる Vision のラベル。料理以外は空。
    /// 提案で料理のタグを決めるのは Worker なので、今はアプリの中では使っていない（data-model.md と同じ表を持つだけ）。
    var visionLabels: [String] {
        switch self {
        case .ramen: ["ramen"]
        case .pasta: ["pasta", "spaghetti"]
        case .sushi: ["sushi"]
        case .curry: ["curry"]
        case .gyoza: ["gyoza", "dumpling"]
        case .tempura: ["tempura"]
        case .karaage: ["fried_chicken"]
        case .pizza: ["pizza"]
        case .hamburger: ["hamburger"]
        case .steak: ["steak"]
        case .sandwich: ["sandwich"]
        case .coffee: ["coffee"]
        case .tea: ["tea_drink"]
        case .alcohol: ["beer", "wine", "red_wine", "white_wine", "sparkling_wine", "cocktail", "liquor"]
        case .juice: ["juice", "smoothie"]
        case .bubbleTea: ["bubble_tea"]
        case .cake: ["cake", "cake_regular", "birthday_cake", "cheesecake", "cupcake"]
        case .iceCream: ["ice_cream"]
        case .donut: ["donut"]
        case .bakedSweets: ["cookie", "muffin", "pie"]
        default: []
        }
    }

    /// 料理のタグから決まる大分類。決まらない料理と、料理以外は `nil`。
    var category: Tag? {
        switch self {
        case .ramen, .pasta: .noodles
        case .sushi, .curry: .riceDish
        case .tempura, .karaage: .fried
        case .hamburger, .sandwich: .bread
        case .steak: .meat
        default: nil
        }
    }

    /// 料理のタグから決まる系統。決まらない料理と、料理以外は `nil`。
    var cuisine: Tag? {
        switch self {
        case .ramen, .gyoza: .chinese
        case .pasta, .pizza, .hamburger, .steak, .sandwich: .western
        case .sushi, .tempura: .japanese
        default: nil
        }
    }

    /// ある種類のタグを、一覧の順で返す。
    static func tags(of kind: TagKind) -> [Tag] {
        allCases.filter { $0.kind == kind }
    }
}
