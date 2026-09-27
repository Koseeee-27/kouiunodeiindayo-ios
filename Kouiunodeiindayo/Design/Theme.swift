import SwiftUI

/// 色・線の太さ・文字の定義。画面ごとに値を直書きせず、ここを参照する。
/// 配色の正はチームの Notion「デザイン要件書」の確定版（マンガのコマ）。ダーク用の色は未定なので、アプリは明るい表示に固定している（`Config/Base.xcconfig`）。
/// 赤はハンコ・スタンプだけに使う。例外は、仕分けの提案のしるし（提案されたジャンルのラベルを囲む点線。`suggestionMark`）。
enum Theme {
    /// 墨。文字（主）と線の元の色
    /// Asset の AccentColor（`main`）にも同じ値を入れている。Asset はコードから値を読めないので、墨を変えるときは両方を直す
    private static let ink = Color(hex: 0x26221F)

    /// メイン（ボタン・強調）。値は `Assets.xcassets` の AccentColor
    /// （アプリ全体の強調色 tint と `.borderedProminent` もそこから決まる）。
    /// 文字・線とは役割が別なので、`ink` にはぶら下げない（強調色を変えても文字の色は変わらない）
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
    static let textPrimary = ink
    /// 文字（副）
    static let textSecondary = Color(hex: 0x6E6862)
    /// 文字（副）より濃く、墨（文字（主））ほどは濃くない文字。副の文字のうち、目に留めたいもの（取り込みの枚数の行など）に使う
    static let textSecondaryStrong = Color(hex: 0x4A4540)
    /// 線・区切り
    static let line = ink

    /// 提案のしるし（仕分けで、提案されたジャンルのラベルを囲む点線）。赤の例外（冒頭の決まり）
    static let suggestionMark = accent
    /// 提案のしるしの点線の太さ
    static let lineWidthSuggestion: CGFloat = 2
    /// 提案のしるしの点線の間隔（線の長さ・空きの長さ）
    static let suggestionDash: [CGFloat] = [5, 4]
    /// 提案のしるしを、ラベルの縁からどれだけ外に離すか
    static let suggestionMarkOffset: CGFloat = 4
    /// 仕分けのタグのチップの「−」「＋」の丸の地
    static let chipSymbolBackground = textSecondary.opacity(0.2)
    /// 仕分けのタグのチップの「−」「＋」の丸の直径（文字サイズが標準のとき。`@ScaledMetric` で文字サイズに合わせる）
    static let chipSymbolSize: CGFloat = 18
    /// 仕分けのタグのチップの内側の余白（右は「−」「＋」の丸があるので狭く）
    static let chipPadding = EdgeInsets(top: 7, leading: 13, bottom: 7, trailing: 9)
    /// 仕分けのタグのチップの、名前と「−」「＋」の丸の間
    static let chipInnerSpacing: CGFloat = 4
    /// 仕分けのタグのチップ同士の間
    static let chipSpacing: CGFloat = 8
    /// 仕分けの下のラベルと、その下のタグの行の間
    static let sortBelowLabelSpacing: CGFloat = 4

    /// 太い線（見出しの下の区切りなど）。太さは仮
    static let lineWidthThick: CGFloat = 2
    /// 細い線（記録の詳細のジャンルのボタンの枠）
    static let lineWidthThin: CGFloat = 1
    /// 押せる部品の高さの下限（Apple の Human Interface Guidelines の目安）
    static let minTapHeight: CGFloat = 44
    /// 小さめの角丸（記録の詳細のジャンルのボタン）
    static let cornerRadiusSmall: CGFloat = 8
    /// 記録の詳細で、写真と日付の間隔。近づけて、ひとまとまりに見せる
    static let detailPhotoDateSpacing: CGFloat = 8
    /// 記録の詳細の「うまい」の絵の幅
    static let detailFavoriteBadgeWidth: CGFloat = 150

    /// 仕分け待ちへの入口の吹き出しの線
    static let lineWidthBubble: CGFloat = 1.5
    /// 仕分けのスタンプの枠。形と一緒に仮
    static let lineWidthStamp: CGFloat = 4
    /// 写真のコマ枠（主役：ホームの今日の一枚・仕分けのカード）
    static let photoFrameWidthMain: CGFloat = 2
    /// 写真のコマ枠（小さい写真：ホームの最近の写真・一覧・記録の詳細）
    static let photoFrameWidthSmall: CGFloat = 1.5

    /// 写真の縦横比（幅 3・高さ 4。iPhone の標準のカメラで縦に構えて撮ったときと同じ）。
    /// 仕分けのカード・ホームの今日の一枚・記録の詳細で使う。一覧とホームの最近の写真は正方形
    static let photoAspectRatio: CGFloat = 3.0 / 4.0

    /// 「うまい」のハンコの傾き。左下がり（SwiftUI は左回りがマイナス）。仕分けの画面と一覧は、それぞれ `sortFavoriteTilt`・`listFavoriteTilt` を使う。この値はホームで使う
    static let favoriteTilt = Angle.degrees(-6)

    /// 一覧の「うまい」のハンコの傾き。右肩下がり（SwiftUI は右回りがプラス）
    static let listFavoriteTilt = Angle.degrees(20)
    /// 一覧の「うまい」のハンコの幅
    static let listFavoriteBadgeWidth: CGFloat = 48
    /// ホームの今日の一枚の幅の、画面の横幅に対する割合（デザインの画像の比率。3:4 なので、高さは幅の 4/3）
    static let todayPhotoWidthRatio: CGFloat = 0.95
    /// ホームの今日の一枚の「うまい」のハンコの幅の、画面の横幅に対する割合（傾き・ずらす割合は一覧と同じ）。傾けると横に広がるので、デザインの大きさより少し小さく取る
    static let todayFavoriteBadgeWidthRatio: CGFloat = 0.42

    /// 一覧の「うまい」のハンコを、右上の角から右へずらす量
    static let listFavoriteBadgeOffsetX: CGFloat = 6
    /// 一覧の「うまい」のハンコを、右上の角から下へずらす量
    static let listFavoriteBadgeOffsetY: CGFloat = 2

    /// 仕分けの画面の「う、うまい」のハンコの傾き。右肩下がり（SwiftUI は右回りがプラス）
    static let sortFavoriteTilt = Angle.degrees(18)

    // 「うまい」を付けたときのハンコを押す演出（機能24。`Design/StampPressEffect.swift`）。値は実機で見て直す
    /// 押した瞬間の大きさ（そこから縮んで 1 倍に止まる）
    static let stampPressScale: CGFloat = 1.4
    /// 縮みきったときの大きさ（1 倍より少し小さくして、ドンと押した弾みを出す）
    static let stampPressUndershoot: CGFloat = 0.95
    /// 押した瞬間の傾き（元の傾きに足す。そこから 0 に戻る）
    static let stampPressTilt = Angle.degrees(8)
    /// 縮んで止まるまでの時間（秒）
    static let stampPressDuration: Double = 0.25
    /// 周りに広がる輪の、広がりきったときの大きさ（絵に対する倍率）
    static let stampPressRingScale: CGFloat = 1.3
    /// 輪の最初の濃さ（そこから消える）
    static let stampPressRingOpacity: Double = 0.6
    /// 輪が広がって消えるまでの時間（秒）
    static let stampPressRingDuration: Double = 0.35
    /// 輪の線の太さと角の丸み。色はハンコの赤（`accent`）
    static let stampPressRingLineWidth: CGFloat = 2
    static let stampPressRingCornerRadius: CGFloat = 12

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
