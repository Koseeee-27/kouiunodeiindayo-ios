/// Vision のラベルから、食事らしい写真かを決める（アルバムからの取り込みの除外。機能18）。
/// 料理の写真には `food` がほぼ必ず出る（`server/scripts/real-labels.tsv` の 6 枚で 0.36〜0.72）。
/// 飲み物・デザートだけの写真は `food` が弱いことがあるので、大きなくくりと料理名のラベルも見る。
enum FoodPhotoFilter {
    /// これ以上の確信度のラベルが 1 つでもあれば食事とする。
    /// 0.10：こうせいの写真 77 枚（正解つき）で、0.30 だと 23%（18 枚）を取りこぼした。0.10 で取りこぼし 5 枚・
    /// 料理でない画像（45 枚）の取り込み 2 枚。取りこぼしは取り込み直すしかないが、料理でないものは仕分けで
    /// 「なし」にできるので、取りこぼしを減らすほうを重く見た（#116）
    static let threshold: Float = 0.10
    /// 大きなくくりのラベル
    static let generalLabels: Set<String> = ["food", "drink", "beverage", "dessert", "baked_goods"]
    /// 大きなくくり＋料理名（`Tag.visionLabels` を全部）
    static let foodLabels: Set<String> = generalLabels.union(Tag.allCases.flatMap(\.visionLabels))

    static func isFood(_ labels: [ImageLabel]) -> Bool {
        labels.contains { foodLabels.contains($0.name) && $0.confidence >= threshold }
    }
}
