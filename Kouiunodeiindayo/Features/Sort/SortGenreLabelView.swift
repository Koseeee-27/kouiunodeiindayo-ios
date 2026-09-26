import SwiftUI

/// 仕分けのラベル。カードの縁に置く吹き出し（左右の尻尾はスワイプする向き、上下の尻尾は写真のほうを指す）。押すと、その向きにスワイプしたのと同じになる。
struct SortGenreLabelView: View {
    enum Emphasis {
        case normal
        /// ドラッグ中、この向きに向いている
        case strong
        /// ドラッグ中、ほかの向きに向いている
        case weak
    }

    /// このラベルでスワイプする向き。上と下のラベルはカードの外にあるので、尻尾は写真のほう（内側）を向く
    let direction: SwipeDirection
    let genre: Genre
    let emphasis: Emphasis
    let action: () -> Void

    /// 尻尾の長さ（pt）
    private static let tailLength: CGFloat = 6

    /// 尻尾を出す辺。上・下のラベルは、カードの外から写真を指す
    private var tailSide: SwipeDirection {
        switch direction {
        case .up: .down
        case .down: .up
        case .left, .right: direction
        }
    }

    var body: some View {
        Button {
            action()
        } label: {
            Label(genre.title, systemImage: genre.systemImage)
                .font(Theme.font(.subheadline, bold: true))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // 色を付けた地の上でも読めるよう、強調中は白にする
                .foregroundStyle(emphasis == .strong ? AnyShapeStyle(Theme.onMain) : AnyShapeStyle(Theme.textPrimary))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                // 尻尾のぶんを、その向きに空けておく
                .padding(tailSide.edge, Self.tailLength)
                .background {
                    let shape = LabelBubbleShape(
                        direction: tailSide, tailLength: Self.tailLength, inset: Theme.lineWidthBubble / 2)
                    // 強調中は、色を付けた地に白い文字にする
                    shape.fill(emphasis == .strong ? Theme.main : Theme.surface)
                    shape.stroke(Theme.line, style: StrokeStyle(lineWidth: Theme.lineWidthBubble, lineJoin: .round))
                }
        }
        .buttonStyle(.plain)
        // 文字サイズを大きくすると、左右のラベル同士が重なるので、Large で止める
        .dynamicTypeSize(...DynamicTypeSize.large)
        .scaleEffect(emphasis == .strong ? 1.15 : 1.0)
        // ほかの向きのラベルも、何のラベルか読める濃さに留める
        .opacity(emphasis == .weak ? 0.6 : 1.0)
        .animation(.easeOut(duration: 0.15), value: emphasis)
        .accessibilityLabel("\(genre.title)にする")
    }
}

/// 角の丸い四角に、`direction` の向きの辺の真ん中から、小さな三角の尻尾を出した形。
/// 尻尾のぶんは `rect` の内側に含める。線の太さの半分（`inset`）だけ内側に描き、線が枠からはみ出さないようにする
private struct LabelBubbleShape: Shape {
    let direction: SwipeDirection
    let tailLength: CGFloat
    let inset: CGFloat

    /// 尻尾の根元の幅
    private static let tailBase: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var frame = rect.insetBy(dx: inset, dy: inset)
        // 本体は、尻尾のぶんを除いた部分
        switch direction {
        case .up:
            frame = CGRect(
                x: frame.minX, y: frame.minY + tailLength, width: frame.width, height: frame.height - tailLength)
        case .down: frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height - tailLength)
        case .left:
            frame = CGRect(
                x: frame.minX + tailLength, y: frame.minY, width: frame.width - tailLength, height: frame.height)
        case .right: frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width - tailLength, height: frame.height)
        }
        let base = Self.tailBase
        // 角の丸みは、尻尾の根元が入るまっすぐな部分（左右の辺）が残る大きさにする
        let radius = (min(frame.width, frame.height) - base) / 2
        let midX = frame.midX
        let midY = frame.midY
        var path = Path()
        path.move(to: CGPoint(x: frame.minX + radius, y: frame.minY))
        if direction == .up {
            path.addLine(to: CGPoint(x: midX - base / 2, y: frame.minY))
            path.addLine(to: CGPoint(x: midX, y: frame.minY - tailLength))
            path.addLine(to: CGPoint(x: midX + base / 2, y: frame.minY))
        }
        path.addArc(
            tangent1End: CGPoint(x: frame.maxX, y: frame.minY),
            tangent2End: CGPoint(x: frame.maxX, y: frame.maxY), radius: radius)
        if direction == .right {
            path.addLine(to: CGPoint(x: frame.maxX, y: midY - base / 2))
            path.addLine(to: CGPoint(x: frame.maxX + tailLength, y: midY))
            path.addLine(to: CGPoint(x: frame.maxX, y: midY + base / 2))
        }
        path.addArc(
            tangent1End: CGPoint(x: frame.maxX, y: frame.maxY),
            tangent2End: CGPoint(x: frame.minX, y: frame.maxY), radius: radius)
        if direction == .down {
            path.addLine(to: CGPoint(x: midX + base / 2, y: frame.maxY))
            path.addLine(to: CGPoint(x: midX, y: frame.maxY + tailLength))
            path.addLine(to: CGPoint(x: midX - base / 2, y: frame.maxY))
        }
        path.addArc(
            tangent1End: CGPoint(x: frame.minX, y: frame.maxY),
            tangent2End: CGPoint(x: frame.minX, y: frame.minY), radius: radius)
        if direction == .left {
            path.addLine(to: CGPoint(x: frame.minX, y: midY + base / 2))
            path.addLine(to: CGPoint(x: frame.minX - tailLength, y: midY))
            path.addLine(to: CGPoint(x: frame.minX, y: midY - base / 2))
        }
        path.addArc(
            tangent1End: CGPoint(x: frame.minX, y: frame.minY),
            tangent2End: CGPoint(x: frame.maxX, y: frame.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

extension SwipeDirection {
    /// 尻尾のぶんの余白を付ける辺
    fileprivate var edge: Edge.Set {
        switch self {
        case .up: .top
        case .down: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}
