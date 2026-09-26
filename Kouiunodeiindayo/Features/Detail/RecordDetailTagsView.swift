import SwiftUI

/// 記録の詳細の、付いているタグの行（機能27）。− で外し、最後の「＋ タグ」でタグの一覧を開く。
/// 折り返して複数行にする（横にスクロールさせると、詳細の左右のめくりと取り合うため）。
/// タグが無いときは「＋ タグを足す」だけを出す。
/// 高さは 2 行分を最低限取る（タグが 1 行の記録と 2 行の記録を左右にめくったときに、写真と日付から下が跳ねないように）。
struct RecordDetailTagsView: View {
    /// 付いているタグ（`record.tagValues`。`Tag.allCases` の順）
    let tags: [Tag]
    let onRemove: (Tag) -> Void
    let onAdd: () -> Void

    var body: some View {
        FlowLayout {
            ForEach(tags, id: \.self) { tag in
                TagChipView(tag: tag, isAttached: true) {
                    onRemove(tag)
                }
            }
            TagAddChipView(hasTags: !tags.isEmpty) {
                onAdd()
            }
        }
        .modifier(TwoRowMinHeight())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("付いているタグ")
        // アクセシビリティサイズでは 1 行に 1 個になり、写真が見えなくなるので、仕分けのタグの行と同じ大きさで止める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.easeOut(duration: 0.15), value: tags)
    }
}

/// タグの行に 2 行分の高さを最低限取る。1 行の高さは、押せる大きさ（44pt）とチップの見た目の高さの大きいほう。
/// `dynamicTypeSize` で止めた文字の大きさで測るよう、止める修飾子より内側に付ける
private struct TwoRowMinHeight: ViewModifier {
    /// チップの見た目の高さ（文字 ＋ 上下の余白）。文字サイズに合わせて大きくする
    @ScaledMetric(relativeTo: .subheadline) private var chipHeight: CGFloat = 34

    func body(content: Content) -> some View {
        let rowHeight = max(Theme.minTapHeight, chipHeight)
        content.frame(minHeight: rowHeight * 2 + Theme.chipSpacing, alignment: .top)
    }
}

#Preview("0 個・3 個・8 個") {
    VStack(alignment: .leading, spacing: 24) {
        RecordDetailTagsView(tags: [], onRemove: { _ in }, onAdd: {})
        RecordDetailTagsView(tags: [.ramen, .noodles, .chinese], onRemove: { _ in }, onAdd: {})
        RecordDetailTagsView(
            tags: [.ramen, .gyoza, .karaage, .noodles, .riceDish, .fried, .chinese, .japanese],
            onRemove: { _ in }, onAdd: {})
    }
    .padding(.horizontal, 16)
    .frame(width: 375)
    .background(Theme.background)
}

#Preview("文字サイズ最大（xxxLarge で止まる）") {
    RecordDetailTagsView(tags: [.ramen, .noodles, .chinese, .japanese], onRemove: { _ in }, onAdd: {})
        .padding(.horizontal, 16)
        .frame(width: 375)
        .background(Theme.background)
        .dynamicTypeSize(.accessibility5)
}
