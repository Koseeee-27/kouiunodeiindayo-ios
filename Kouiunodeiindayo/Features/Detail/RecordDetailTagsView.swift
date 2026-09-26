import SwiftUI

/// 記録の詳細の、付いているタグの行（機能27）。− で外し、最後の「＋ タグ」でタグの一覧を開く。
/// 折り返して複数行にする（横にスクロールさせると、詳細の左右のめくりと取り合うため）。
/// タグが無いときは「＋ タグを足す」だけを出す。
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("付いているタグ")
        // アクセシビリティサイズでは 1 行に 1 個になり、写真が見えなくなるので、仕分けのタグの行と同じ大きさで止める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.easeOut(duration: 0.15), value: tags)
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
