import SwiftUI

/// 色と線の太さの定義。画面ごとに値を直書きせず、ここを参照する。
/// 配色の正はチームの Notion「デザイン要件書」の確定版（マンガのコマ）。ダーク用の色は未定なので、アプリは明るい表示に固定している（`Config/Base.xcconfig`）。
/// アプリ全体の強調色（tint）は `Assets.xcassets` の AccentColor（`main` と同じ墨）。赤はハンコ・スタンプだけに使う。
enum Theme {
    /// メイン（ボタン・強調）。墨
    static let main = Color(hex: 0x26221F)
    /// アクセント（「うまい」のハンコ・仕分けのスタンプ）。赤
    static let accent = Color(hex: 0xCC3327)
    /// 背景（画面の地）
    static let background = Color(hex: 0xF9F6EE)
    /// 背景の段差（カード・写真の読み込み中など、一段上の面）
    static let surface = Color(hex: 0xFFFFFF)
    /// 文字（主）
    static let textPrimary = Color(hex: 0x26221F)
    /// 文字（副）
    static let textSecondary = Color(hex: 0x6E6862)
    /// 線・区切り
    static let line = Color(hex: 0x26221F)

    /// 線の太さ（仮）。Figma の 4px は強いので細くしている
    static let lineWidth: CGFloat = 1
}

extension Color {
    /// `0xRRGGBB` の形の値から、sRGB の色を作る
    fileprivate init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
