import SwiftUI

/// 仕分けのラベル。カードの重なりの縁に重ねるチップ。押すと、その向きにスワイプしたのと同じになる。
struct SortGenreLabelView: View {
    enum Emphasis {
        case normal
        /// ドラッグ中、この向きに向いている
        case strong
        /// ドラッグ中、ほかの向きに向いている
        case weak
    }

    let genre: Genre
    let emphasis: Emphasis
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(genre.title, systemImage: genre.systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // 色を付けた地の上でも読めるよう、強調中は白にする
                .foregroundStyle(emphasis == .strong ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // 見た目は仮（Liquid Glass はトーンが決まったら #23 で見直す）
                .glassEffect(emphasis == .strong ? .regular.tint(.accentColor) : .regular, in: .capsule)
        }
        .buttonStyle(.plain)
        // 文字サイズを XX Large 以上にすると、上のラベルと「う、うまい」、左右のラベル同士が重なるので上限を付ける
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .scaleEffect(emphasis == .strong ? 1.15 : 1.0)
        // ほかの向きのラベルも、何のラベルか読める濃さに留める
        .opacity(emphasis == .weak ? 0.6 : 1.0)
        .animation(.easeOut(duration: 0.15), value: emphasis)
        .accessibilityLabel("\(genre.title)にする")
    }
}
