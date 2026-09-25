import SwiftUI

/// 色・線の太さ・文字の定義。画面ごとに値を直書きせず、ここを参照する。
/// 配色の正はチームの Notion「デザイン要件書」の確定版（マンガのコマ）。ダーク用の色は未定なので、アプリは明るい表示に固定している（`Config/Base.xcconfig`）。
/// 赤はハンコ・スタンプだけに使う。
enum Theme {
    /// メイン（ボタン・強調）。墨。値は `Assets.xcassets` の AccentColor が正
    /// （アプリ全体の強調色 tint と `.borderedProminent` もそこから墨になるので、値を1か所にまとめている）
    static let main = Color.accentColor
    /// メインの地の上に置く文字・アイコン
    static let onMain = Color(hex: 0xFFFFFF)
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

    /// 細い線（写真の枠など）。太さは仮。Figma の 4px は強いので細くしている
    static let lineWidthThin: CGFloat = 1
    /// 太い線（見出しの下の区切りなど）。太さは仮
    static let lineWidthThick: CGFloat = 2
    /// 仕分けのスタンプの枠。形と一緒に仮
    static let lineWidthStamp: CGFloat = 4

    /// 文字。游ゴシックは iOS に入っていないので、見た目の近いヒラギノ角ゴで代わりにする。
    /// 文字サイズの設定に追従させるため、`relativeTo:` で標準の文字の種類に合わせる
    static func font(_ style: Font.TextStyle, bold: Bool = false) -> Font {
        .custom(bold ? "HiraginoSans-W6" : "HiraginoSans-W3", size: style.defaultSize, relativeTo: style)
    }
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

extension Font.TextStyle {
    /// 文字サイズが標準の設定のときの大きさ（Apple の Human Interface Guidelines の表の値）
    fileprivate var defaultSize: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}
