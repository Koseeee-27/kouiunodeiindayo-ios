import SwiftUI

/// 仕分けのラベル。押すと、その向きにスワイプしたのと同じになる。
struct SortGenreLabelView: View {
    enum Emphasis {
        case normal
        /// ドラッグ中、この向きに向いている
        case strong
        /// ドラッグ中、ほかの向きに向いている
        case weak
    }

    let genre: Genre
    /// 左右のラベルは、カードの幅を取らないようアイコンと文字を縦に積む（文字は横書き）
    let isVertical: Bool
    let emphasis: Emphasis
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if isVertical {
                    VStack(spacing: 4) {
                        Image(systemName: genre.systemImage)
                        Text(genre.title)
                    }
                } else {
                    Label(genre.title, systemImage: genre.systemImage)
                }
            }
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(emphasis == .strong ? 1.2 : 1.0)
        .opacity(emphasis == .weak ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.15), value: emphasis)
        .accessibilityLabel("\(genre.title)にする")
    }
}
