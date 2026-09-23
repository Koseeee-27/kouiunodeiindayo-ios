import Foundation

/// アプリから開く外部ページの URL。設定画面のリンクはここから取る。
/// 強制アンラップを使わないため、`URL(string:)` の結果のまま `URL?` で持つ
enum AppLinks {
    /// LP の土台の URL。LP の公開先が決まったら差し替える（仮の値）。
    /// 正は kouiunodeiindayo-lp の `docs/pages.md`
    private static let base = "https://example.com"

    static let privacyPolicy = URL(string: "\(base)/privacy")
    static let support = URL(string: "\(base)/support")
}
