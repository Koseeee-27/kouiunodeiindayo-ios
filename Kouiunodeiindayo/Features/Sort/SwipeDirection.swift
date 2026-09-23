import SwiftUI

/// 仕分けのスワイプの向きと、向きごとのジャンル。向きとジャンルの対応は `docs/screen-design.md` の「仕分け」が正。
/// 手触り（どこまで動かせば仕分けるか・傾き）の調整は、このファイルの定数を直す（実機で決める）。
enum SwipeDirection: CaseIterable {
    case up
    case left
    case right
    case down

    /// これ以上動かして離すと仕分ける（pt）。
    static let commitDistance: CGFloat = 100
    /// 払ったとき、離した後に進むと予測される位置がこれ以上なら、短く動かしただけでも仕分ける（pt）。
    static let flickDistance: CGFloat = 250
    /// これ以上動かすと、その向きのラベルを強調する（pt）。
    static let highlightDistance: CGFloat = 20
    /// 横に何 pt 動かすと 1 度傾けるか。
    static let pointsPerDegree: CGFloat = 20
    /// 傾きの上限（度）。
    static let maxRotationDegrees: Double = 15

    var genre: Genre {
        switch self {
        case .up: .food
        case .left: .drink
        case .right: .dessert
        case .down: .noGenre
        }
    }

    /// ドラッグ中の移動量から、いま向いている向き。縦横の大きいほうを採る。動きが小さければ nil。
    static func direction(for translation: CGSize) -> SwipeDirection? {
        guard let direction = mainDirection(of: translation),
            direction.distance(of: translation) >= highlightDistance
        else { return nil }
        return direction
    }

    /// 指を離したときに仕分けるなら、その向き。
    /// 向きは移動量で決め、予測位置は同じ向きのときだけ見る（払った勢いで逆向きに飛ばないように）。
    static func committed(translation: CGSize, predictedEndTranslation: CGSize) -> SwipeDirection? {
        guard let direction = mainDirection(of: translation) else { return nil }
        if direction.distance(of: translation) >= commitDistance
            || direction.distance(of: predictedEndTranslation) >= flickDistance
        {
            return direction
        }
        return nil
    }

    /// ドラッグ中のカードの傾き。横に動かすほど傾き、上限で止まる。
    static func rotation(for translation: CGSize) -> Angle {
        let degrees = Double(translation.width / pointsPerDegree)
        return .degrees(min(max(degrees, -maxRotationDegrees), maxRotationDegrees))
    }

    /// 仕分けたカードを飛ばす先。画面の外に出るよう、画面の大きさの 1.5 倍動かす。
    func offscreenOffset(in size: CGSize) -> CGSize {
        switch self {
        case .up: CGSize(width: 0, height: -size.height * 1.5)
        case .left: CGSize(width: -size.width * 1.5, height: 0)
        case .right: CGSize(width: size.width * 1.5, height: 0)
        case .down: CGSize(width: 0, height: size.height * 1.5)
        }
    }

    /// その向きに進んだ量（逆向きなら負）。
    private func distance(of translation: CGSize) -> CGFloat {
        switch self {
        case .up: -translation.height
        case .left: -translation.width
        case .right: translation.width
        case .down: translation.height
        }
    }

    /// 縦横の大きいほうの向き。まったく動いていなければ nil。
    private static func mainDirection(of translation: CGSize) -> SwipeDirection? {
        if translation == .zero { return nil }
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        }
        return translation.height > 0 ? .down : .up
    }
}
