import SwiftUI

/// 仕分けのスワイプの向きと、向きごとのジャンル。向きとジャンルの対応は `docs/screen-design.md` の「仕分け」が正。
/// 手触り（どこまで動かせば仕分けるか・傾き・飛び方・後ろのカード）の調整は、このファイルの定数を直す（実機で決める）。
enum SwipeDirection {
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
    /// 離した瞬間の速さがこれ以上なら、払った向き（斜めも可）にそのまま飛ばす（pt/秒）。これ未満なら仕分けの向きにまっすぐ。
    static let flingMinSpeed: CGFloat = 300
    /// 飛ばす時間の下限・上限（秒）。速く払っても一瞬で消えず、ゆっくりでももたつかないようにする。
    static let flyMinDuration: TimeInterval = 0.12
    static let flyMaxDuration: TimeInterval = 0.35
    /// 飛ばすとき、カードの重なりの枠の外にある画面の分（上の行・左右の余白・ホームインジケーター）として足す余白（pt）。
    static let flyOutMargin: CGFloat = 100
    /// 後ろのカードの大きさ（手前のカードに対する倍率）。
    static let backCardScale: CGFloat = 0.92
    /// 手前のカードの下の隙間から、後ろのカードの下端が見える高さ（pt）。
    static let backCardPeek: CGFloat = 10

    var genre: Genre {
        switch self {
        case .up: .food
        case .left: .drink
        case .right: .dessert
        case .down: .noGenre
        }
    }

    /// 提案のジャンルから向きを引く（おまかせで、提案のジャンルの向きへ飛ばすため）。
    /// 提案できるジャンル（食べ物・飲み物・デザート）だけ。「なし」と仕分け待ちは提案されないので nil。
    init?(suggestedGenre genre: Genre) {
        switch genre {
        case .food: self = .up
        case .drink: self = .left
        case .dessert: self = .right
        case .noGenre, .unsorted: return nil
        }
    }

    /// ドラッグ中の移動量から、いま向いている向き。縦横の大きいほうを採る。動きが小さければ nil。
    static func direction(for translation: CGSize) -> SwipeDirection? {
        guard let direction = mainDirection(of: translation),
            direction.distance(of: translation) >= highlightDistance
        else { return nil }
        return direction
    }

    /// 離せば仕分けになる距離（`commitDistance`）まで進んでいれば、その向き。超えた瞬間に振動させるのに使う。
    static func pendingCommit(for translation: CGSize) -> SwipeDirection? {
        guard let direction = mainDirection(of: translation),
            direction.distance(of: translation) >= commitDistance
        else { return nil }
        return direction
    }

    /// 主な向きに、離せば仕分けになる距離のどこまで進んだか（0〜1）。スタンプの濃さと、後ろのカードのせり上がりに使う。
    static func progress(for translation: CGSize) -> CGFloat {
        guard let direction = mainDirection(of: translation) else { return 0 }
        return min(max(direction.distance(of: translation) / commitDistance, 0), 1)
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

    /// スワイプで仕分けたカードを飛ばす先と時間。`translation` は離した瞬間の位置、`velocity` は離した瞬間の速さ（pt/秒）、
    /// `size` はカードの重なりの枠の大きさ。カード（3:4）は枠より小さいので、カードを枠の大きさとみなして少し余分に飛ぶ
    /// （画面の外に出きるのは変わらず、時間は上限・下限に収める）。
    /// 速さの主な向きが仕分けの向きと同じ（仕分けの向きから ±45° 以内）なら、その速さの向き（斜めも可）に飛ばす。
    /// そうでなければ仕分けの向きにまっすぐ（仕分けたジャンルと違う向きへ飛んでいくように見えないように）。
    /// 距離は、離した位置からカードが画面の外に出きるまで。時間は「その距離 ÷ 離した瞬間の速さ」を上限・下限に収めたもの。
    /// 呼ぶ側は `.linear` で動かすので、上限・下限に掛からなければ、離した瞬間の速さのまま画面の外へ出る。
    static func flight(from translation: CGSize, velocity: CGSize, direction: SwipeDirection, in size: CGSize)
        -> (offset: CGSize, duration: TimeInterval)
    {
        let speed = hypot(velocity.width, velocity.height)
        let unit: CGSize
        if speed >= flingMinSpeed, mainDirection(of: velocity) == direction {
            unit = CGSize(width: velocity.width / speed, height: velocity.height / speed)
        } else {
            unit = direction.unitVector
        }
        let distance = exitDistance(from: translation, unit: unit, in: size)
        let offset = CGSize(
            width: translation.width + unit.width * distance,
            height: translation.height + unit.height * distance
        )
        let duration = speed > 0 ? TimeInterval(distance / speed) : flyMaxDuration
        return (offset, min(max(duration, flyMinDuration), flyMaxDuration))
    }

    /// カードの真ん中が `translation` の位置から `unit` の向きに進んで、カード全体が画面の外に出きるまでの距離。
    /// カードは最大 `maxRotationDegrees` 傾くので、傾いたカードを囲む箱の大きさで見る。
    /// 枠の外（上の行・左右の余白・ホームインジケーター）の分は `flyOutMargin` で足す。
    private static func exitDistance(from translation: CGSize, unit: CGSize, in size: CGSize) -> CGFloat {
        let radians = maxRotationDegrees * .pi / 180
        let cardHalfWidth = (size.width * cos(radians) + size.height * sin(radians)) / 2
        let cardHalfHeight = (size.height * cos(radians) + size.width * sin(radians)) / 2
        // カードの真ん中がこの範囲の外に出れば、カード全体が画面の外にある（枠の真ん中からの距離）
        let limitX = size.width / 2 + flyOutMargin + cardHalfWidth
        let limitY = size.height / 2 + flyOutMargin + cardHalfHeight
        func distance(position: CGFloat, direction: CGFloat, limit: CGFloat) -> CGFloat {
            if direction > 0 { return (limit - position) / direction }
            if direction < 0 { return (-limit - position) / direction }
            return .infinity
        }
        let distanceX = distance(position: translation.width, direction: unit.width, limit: limitX)
        let distanceY = distance(position: translation.height, direction: unit.height, limit: limitY)
        return max(min(distanceX, distanceY), 0)
    }

    /// その向きの長さ 1 のベクトル。
    private var unitVector: CGSize {
        switch self {
        case .up: CGSize(width: 0, height: -1)
        case .left: CGSize(width: -1, height: 0)
        case .right: CGSize(width: 1, height: 0)
        case .down: CGSize(width: 0, height: 1)
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
