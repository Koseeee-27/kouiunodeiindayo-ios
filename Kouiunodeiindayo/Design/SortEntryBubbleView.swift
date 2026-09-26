import SwiftUI

/// ホームと一覧の「仕分け待ちへの入口」。マンガのコマに合わせて、白の地に墨の線で囲んだ吹き出しの形にする。
/// 押したときの動きは呼び出し側が `action` で決める。仕分け待ちが 0 枚のときは、呼び出し側が出さない。
struct SortEntryBubbleView: View {
    /// 仕分け待ちの枚数
    let count: Int
    let action: () -> Void

    /// 尻尾（吹き出しの口）の高さ。文字サイズに関わらず固定
    private static let tailHeight: CGFloat = 14

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "tray.full")
                Text("仕分け待ち \(count) 枚")
                    .font(Theme.font(.headline, bold: true))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            // 尻尾のぶんの高さを、下に空けておく
            .padding(.bottom, Self.tailHeight)
            .background {
                SpeechBubbleShape(tailHeight: Self.tailHeight, inset: Theme.lineWidthBubble / 2)
                    .fill(Theme.surface)
                SpeechBubbleShape(tailHeight: Self.tailHeight, inset: Theme.lineWidthBubble / 2)
                    .stroke(Theme.line, style: StrokeStyle(lineWidth: Theme.lineWidthBubble, lineJoin: .round))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("仕分け待ち \(count) 枚。仕分けを始める")
    }
}

/// 角の丸い四角の左下に、下向きの尻尾を付けた形。線の太さの半分（`inset`）だけ内側に描き、線が枠からはみ出さないようにする
private struct SpeechBubbleShape: Shape {
    /// 尻尾の高さ
    let tailHeight: CGFloat
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: inset, dy: inset)
        // 本体は、尻尾のぶんを除いた上の部分
        let body = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height - tailHeight)
        let radius = min(body.height / 2, 28)
        // 尻尾は、左下の角の丸みが終わったあとの、まっすぐな辺から出す
        let tailStart = body.minX + radius + 8
        let tailWidth: CGFloat = 20
        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addArc(
            tangent1End: CGPoint(x: body.maxX, y: body.minY),
            tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: radius)
        path.addArc(
            tangent1End: CGPoint(x: body.maxX, y: body.maxY),
            tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: radius)
        path.addLine(to: CGPoint(x: tailStart + tailWidth, y: body.maxY))
        path.addLine(to: CGPoint(x: tailStart + 2, y: frame.maxY))
        path.addLine(to: CGPoint(x: tailStart, y: body.maxY))
        path.addArc(
            tangent1End: CGPoint(x: body.minX, y: body.maxY),
            tangent2End: CGPoint(x: body.minX, y: body.minY), radius: radius)
        path.addArc(
            tangent1End: CGPoint(x: body.minX, y: body.minY),
            tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        SortEntryBubbleView(count: 3, action: {})
        SortEntryBubbleView(count: 128, action: {})
    }
    .padding()
    .background(Theme.background)
}

#Preview("文字サイズ最大") {
    SortEntryBubbleView(count: 3, action: {})
        .padding()
        .background(Theme.background)
        .dynamicTypeSize(.accessibility3)
}
