import SwiftUI

/// 仕分けで、提案されたタグ（機能26・27）をカードの下に − つきのチップで並べる。
/// 押すと外れて点線の枠と ＋ になり、もう一度押すと付く。写真は次に進まない。
/// 提案が無いとき（届く前・通信できない・提案なし）も、1 行分の高さを空けておく（届いたときにカードが縮まないように）。
/// 1 行に入りきらないときは、折り返さずに横にスクロールする。
/// 提案が届くのを待っている間は、空けた 1 行の場所に「提案を待っています…」を薄く出す（#120。文言は仮）。
struct SortSuggestedTagsView: View {
    /// 提案されたタグ（`record.suggestedTagValues`）
    let tags: [Tag]
    /// 外したタグ
    let removed: Set<Tag>
    /// カードが飛んでいる間は false にして、押せなくする
    let isEnabled: Bool
    /// 提案が届くのを待っている（`SuggestionService.isPending`）
    var isWaiting = false
    let onToggle: (Tag) -> Void

    var body: some View {
        ZStack {
            // 高さを決めるための見えないチップ。提案が無いときも 1 行分を空ける
            TagChipView(tag: .ramen, isAttached: true) {}
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
            } else if isWaiting {
                Text("提案を待っています…")
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .accessibilityLabel("提案を待っています")
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(isEnabled)
        // 文字サイズを大きくしても 1 行に収めるため、アクセシビリティサイズの手前で止める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.easeOut(duration: 0.15), value: tags)
        .animation(.easeOut(duration: 0.15), value: isWaiting)
    }

    private var row: some View {
        HStack(spacing: Theme.chipSpacing) {
            ForEach(tags, id: \.self) { tag in
                TagChipView(tag: tag, isAttached: !removed.contains(tag)) {
                    onToggle(tag)
                }
            }
        }
    }
}

#Preview("全部付いている・1つ外した・5個・空・待っている") {
    VStack(spacing: 24) {
        SortSuggestedTagsView(tags: [.tempura, .fried, .japanese], removed: [], isEnabled: true) { _ in }
        SortSuggestedTagsView(tags: [.tempura, .fried, .japanese], removed: [.japanese], isEnabled: true) { _ in }
        SortSuggestedTagsView(
            tags: [.ramen, .gyoza, .noodles, .chinese, .japanese], removed: [.japanese], isEnabled: true
        ) { _ in }
        SortSuggestedTagsView(tags: [], removed: [], isEnabled: true) { _ in }
            .border(Theme.textSecondary)
        SortSuggestedTagsView(tags: [], removed: [], isEnabled: true, isWaiting: true) { _ in }
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
