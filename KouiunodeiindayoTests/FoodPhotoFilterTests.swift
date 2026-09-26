import Testing

@testable import Kouiunodeiindayo

@MainActor
struct FoodPhotoFilterTests {
    /// `server/scripts/real-labels.tsv`（Mac の Vision で無料素材 6 枚から作った実際のラベル）の上位 10 個
    static let realLabels: [String: [(String, Float)]] = [
        "karaage": [
            ("food", 0.36), ("meat", 0.36), ("sausage", 0.36), ("material", 0.31), ("raw_glass", 0.28),
            ("utensil", 0.21), ("tableware", 0.17), ("cookware", 0.1), ("grill", 0.1), ("interior_room", 0.1),
        ],
        "udon": [
            ("structure", 0.86), ("wood_processed", 0.86), ("tableware", 0.81), ("utensil", 0.81), ("bowl", 0.8),
            ("food", 0.65), ("vegetable", 0.64), ("chopsticks", 0.49), ("soup", 0.38), ("document", 0.26),
        ],
        "tempura": [
            ("food", 0.72), ("citrus_fruit", 0.72), ("fruit", 0.72), ("lime", 0.72), ("tableware", 0.3),
            ("utensil", 0.3), ("plate", 0.3), ("fried_chicken", 0.13), ("container", 0.09), ("carton", 0.09),
        ],
        "oyakodon": [
            ("utensil", 0.5), ("tableware", 0.5), ("bowl", 0.5), ("food", 0.5), ("vegetable", 0.46),
            ("tomato", 0.46), ("egg", 0.35), ("yolk", 0.35), ("seasonings", 0.19), ("herb", 0.19),
        ],
        "miso": [
            ("structure", 0.93), ("wood_processed", 0.93), ("tableware", 0.81), ("utensil", 0.81), ("bowl", 0.81),
            ("food", 0.72), ("soup", 0.72), ("plate", 0.13), ("document", 0.08), ("printed_page", 0.08),
        ],
        "bento": [
            ("food", 0.7), ("sushi", 0.7), ("rice", 0.3), ("material", 0.26), ("textile", 0.26),
            ("container", 0.2), ("carton", 0.2), ("utensil", 0.15), ("tableware", 0.15), ("machine", 0.15),
        ],
    ]

    static func labels(_ pairs: [(String, Float)]) -> [ImageLabel] {
        pairs.map { ImageLabel(name: $0.0, confidence: $0.1) }
    }

    @Test(arguments: ["karaage", "udon", "tempura", "oyakodon", "miso", "bento"])
    func 実際の料理の写真は全部食事になる(name: String) throws {
        let pairs = try #require(Self.realLabels[name])
        #expect(FoodPhotoFilter.isFood(Self.labels(pairs)))
    }

    @Test func 机とキーボードは食事でない() {
        #expect(!FoodPhotoFilter.isFood(Self.labels([("desk", 0.6), ("keyboard", 0.45), ("computer", 0.2)])))
    }

    @Test func コーヒーは料理名のラベルで食事になる() {
        #expect(FoodPhotoFilter.isFood(Self.labels([("coffee", 0.8), ("cup", 0.3)])))
    }

    @Test func しきい値の境目() {
        #expect(!FoodPhotoFilter.isFood(Self.labels([("food", 0.09)])))
        #expect(FoodPhotoFilter.isFood(Self.labels([("food", 0.10)])))
    }

    /// こうせいの写真で、0.30 のときに取りこぼしていた料理・デザート（食べ物系のラベルが 0.10〜0.30）
    @Test(arguments: [("food", Float(0.21)), ("dessert", 0.26), ("baked_goods", 0.10)])
    func 食べ物系のラベルが弱い料理とデザートも食事になる(name: String, confidence: Float) {
        #expect(FoodPhotoFilter.isFood(Self.labels([(name, confidence), ("tableware", 0.4)])))
    }

    @Test func 食べ物系のラベルがとても弱い写真は食事でない() {
        // food が 0.05 しか出ない写真は除く（こうせいの写真では、食べ物系が 0.05〜0.07 の料理 3 枚が取りこぼしとして残る。
        // 取りこぼすデザート 2 枚は、食べ物系のラベルがほぼ出ない（0〜0.01））
        #expect(!FoodPhotoFilter.isFood(Self.labels([("food", 0.05), ("carton", 0.6)])))
    }

    @Test func ラベルが無ければ食事でない() {
        #expect(!FoodPhotoFilter.isFood([]))
    }
}
