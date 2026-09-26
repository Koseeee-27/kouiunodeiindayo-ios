/// Vision のラベルから、食事らしい写真かを決める（アルバムからの取り込みの除外。機能18）。
/// 料理の写真には `food` がほぼ必ず出る（`server/scripts/real-labels.tsv` の 6 枚で 0.36〜0.72）。
/// 飲み物・デザートだけの写真は `food` が弱いことがあるので、大きなくくりと料理名のラベルも見る。
enum FoodPhotoFilter {
    /// これ以上の確信度のラベルが 1 つでもあれば食事とする。実機で外れを見て直す
    static let threshold: Float = 0.30
    /// 大きなくくりのラベル
    static let generalLabels: Set<String> = ["food", "drink", "beverage", "dessert", "baked_goods"]
    /// 大きなくくり＋料理名（`Tag.visionLabels` を全部）
    static let foodLabels: Set<String> = generalLabels.union(Tag.allCases.flatMap(\.visionLabels))

    static func isFood(_ labels: [ImageLabel]) -> Bool {
        labels.contains { foodLabels.contains($0.name) && $0.confidence >= threshold }
    }
}
