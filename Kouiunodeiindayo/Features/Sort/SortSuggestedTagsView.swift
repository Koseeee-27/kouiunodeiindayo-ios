import SwiftUI

/// 仕分けで、提案されたタグ（機能26・27）をカードの下に − つきのチップで並べる。
/// 押すと外れて点線の枠と ＋ になり、もう一度押すと付く。写真は次に進まない。
/// 提案が無いとき（届く前・通信できない・提案なし）も、1 行分の高さを空けておく（届いたときにカードが縮まないように）。
/// 1 行に入りきらないときは、折り返さずに横にスクロールする。
struct SortSuggestedTagsView: View {
    /// 提案されたタグ（`record.suggestedTagValues`）
    let tags: [Tag]
    /// 外したタグ
    let removed: Set<Tag>
    /// カードが飛んでいる間は false にして、押せなくする
    let isEnabled: Bool
    let onToggle: (Tag) -> Void

    /// チップ同士の間隔（pt）
    private static let spacing: CGFloat = 8

    var body: some View {
        ZStack {
            // 高さを決めるための見えないチップ。提案が無いときも 1 行分を空ける
            SortTagChipView(tag: .ramen, isAttached: true) {}
                .hidden()
                .accessibilityHidden(true)
            if !tags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    row
                    ScrollView(.horizontal) {
                        row
                    }
                    .scrollIndicators(.hidden)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("提案されたタグ")
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(isEnabled)
        // 文字サイズを大きくしても 1 行に収めるため、アクセシビリティサイズの手前で止める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.easeOut(duration: 0.15), value: tags)
    }

    private var row: some View {
        HStack(spacing: Self.spacing) {
            ForEach(tags, id: \.self) { tag in
                SortTagChipView(tag: tag, isAttached: !removed.contains(tag)) {
                    onToggle(tag)
                }
            }
        }
    }
}

/// タグのチップ 1 つ。付いている：白地に墨の線と −／外した：点線の枠と ＋（ワイヤー集「タグの見せ方」の 2b）。
private struct SortTagChipView: View {
    let tag: Tag
    let isAttached: Bool
    let action: () -> Void

    /// −・＋ の丸の直径。文字サイズに合わせて大きくする
    @ScaledMetric(relativeTo: .subheadline) private var symbolSize: CGFloat = 18

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Text(tag.title)
                    .font(Theme.font(.subheadline, bold: true))
                    .lineLimit(1)
                Image(systemName: isAttached ? "minus" : "plus")
                    .font(Theme.font(.caption2, bold: true))
                    .frame(width: symbolSize, height: symbolSize)
                    .background(Circle().fill(Theme.chipSymbolBackground))
            }
            .foregroundStyle(isAttached ? Theme.textPrimary : Theme.textSecondary)
            .padding(.leading, 13)
            .padding(.trailing, 9)
            .padding(.vertical, 7)
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
        .accessibilityLabel("タグ \(tag.title)")
        .accessibilityAddTraits(isAttached ? .isSelected : [])
        .accessibilityHint(isAttached ? "押すと外します" : "押すと付けます")
    }
}

#Preview("全部付いている・1つ外した・5個・空") {
    VStack(spacing: 24) {
        SortSuggestedTagsView(tags: [.tempura, .fried, .japanese], removed: [], isEnabled: true) { _ in }
        SortSuggestedTagsView(tags: [.tempura, .fried, .japanese], removed: [.japanese], isEnabled: true) { _ in }
        SortSuggestedTagsView(
            tags: [.ramen, .gyoza, .noodles, .chinese, .japanese], removed: [.japanese], isEnabled: true
        ) { _ in }
        SortSuggestedTagsView(tags: [], removed: [], isEnabled: true) { _ in }
            .border(Theme.textSecondary)
    }
    .padding(.horizontal, 16)
    .frame(width: 375)
    .background(Theme.background)
}

#Preview("文字サイズ最大（xxxLarge で止まる）") {
    VStack(spacing: 24) {
        SortSuggestedTagsView(tags: [.tempura, .fried, .japanese], removed: [.japanese], isEnabled: true) { _ in }
        SortSuggestedTagsView(tags: [.ramen, .noodles, .chinese, .japanese], removed: [], isEnabled: true) { _ in }
    }
    .padding(.horizontal, 16)
    .frame(width: 375)
    .background(Theme.background)
    .dynamicTypeSize(.accessibility5)
}
