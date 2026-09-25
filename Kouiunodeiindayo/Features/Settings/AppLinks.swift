import Foundation

/// アプリから開く外部ページの URL。設定画面のリンクはここから取る。
/// 強制アンラップを使わないため、`URL(string:)` の結果のまま `URL?` で持つ
enum AppLinks {
    /// LP の公開先の URL。正は kouiunodeiindayo-lp の `docs/pages.md`。
    /// 下の 2 つは App Store Connect に登録する URL と同じにする。
    /// 末尾の `/` は付ける（無いと `/` 付きへ転送される）
    private static let base = "https://kouiunodeiindayo-lp.k-27.workers.dev"

    static let privacyPolicy = URL(string: "\(base)/privacy/")
    static let support = URL(string: "\(base)/support/")
}
