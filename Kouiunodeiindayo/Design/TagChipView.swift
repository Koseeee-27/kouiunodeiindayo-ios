import SwiftUI

/// タグのチップ 1 つ。付いている：白地に墨の線と −／外した：点線の枠と ＋（ワイヤー集「タグの見せ方」の 2b）。
/// 仕分けの提案されたタグ・記録の詳細のタグの行・タグの一覧のシート・一覧の言葉で探す条件で共通に使う。
struct TagChipView: View {
    let title: String
    /// 読み上げ
    let accessibilityName: String
    let isAttached: Bool
    let action: () -> Void

    init(tag: Tag, isAttached: Bool, action: @escaping () -> Void) {
        self.init(title: tag.title, accessibilityLabel: "タグ \(tag.title)", isAttached: isAttached, action: action)
    }

    /// タグでないもの（言葉で探す条件の「うまい」「今月」など）を、同じ見た目で出す
    init(title: String, accessibilityLabel: String, isAttached: Bool, action: @escaping () -> Void) {
        self.title = title
        accessibilityName = accessibilityLabel
        self.isAttached = isAttached
        self.action = action
    }

    /// −・＋ の丸の直径。文字サイズに合わせて大きくする
    @ScaledMetric(relativeTo: .subheadline) private var symbolSize = Theme.chipSymbolSize

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Theme.chipInnerSpacing) {
                Text(title)
                    .font(Theme.font(.subheadline, bold: true))
                    .lineLimit(1)
                Image(systemName: isAttached ? "minus" : "plus")
                    .font(Theme.font(.caption2, bold: true))
                    .frame(width: symbolSize, height: symbolSize)
                    .background(Circle().fill(Theme.chipSymbolBackground))
            }
            .foregroundStyle(isAttached ? Theme.textPrimary : Theme.textSecondary)
            .padding(Theme.chipPadding)
            .background {
                let shape = Capsule().inset(by: Theme.lineWidthBubble / 2)
                if isAttached {
                    shape.fill(Theme.surface)
                    shape.stroke(Theme.line, lineWidth: Theme.lineWidthBubble)
                } else {
                    shape.stroke(
                        Theme.textSecondary,
                        style: StrokeStyle(lineWidth: Theme.lineWidthBubble, dash: Theme.suggestionDash))
                }
            }
            // 見た目は小さめのまま、押せる範囲は上下に広げる
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isAttached)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isAttached ? .isSelected : [])
        .accessibilityHint(isAttached ? "押すと外します" : "押すと付けます")
    }
}

/// タグを足す入口のチップ。外したチップと同じ点線の枠に ＋。
/// タグが 1 つも無いときは「タグを足す」、付いているときは「タグ」と短くする。読み上げはどちらも「タグを足す」
struct TagAddChipView: View {
    let hasTags: Bool
    let action: () -> Void

    /// ＋ の丸の直径。`TagChipView` と同じ
    @ScaledMetric(relativeTo: .subheadline) private var symbolSize = Theme.chipSymbolSize

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Theme.chipInnerSpacing) {
                Image(systemName: "plus")
                    .font(Theme.font(.caption2, bold: true))
                    .frame(width: symbolSize, height: symbolSize)
                    .background(Circle().fill(Theme.chipSymbolBackground))
                Text(hasTags ? "タグ" : "タグを足す")
                    .font(Theme.font(.subheadline, bold: true))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(Theme.chipPadding)
            .background {
                Capsule().inset(by: Theme.lineWidthBubble / 2)
                    .stroke(
                        Theme.textSecondary,
                        style: StrokeStyle(lineWidth: Theme.lineWidthBubble, dash: Theme.suggestionDash))
            }
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("タグを足す")
    }
}

#Preview("付いている・外した・足す") {
    VStack(spacing: Theme.chipSpacing) {
        HStack(spacing: Theme.chipSpacing) {
            TagChipView(tag: .ramen, isAttached: true) {}
            TagChipView(tag: .chinese, isAttached: false) {}
        }
        HStack(spacing: Theme.chipSpacing) {
            TagAddChipView(hasTags: true) {}
            TagAddChipView(hasTags: false) {}
        }
    }
    .padding()
    .background(Theme.background)
}
