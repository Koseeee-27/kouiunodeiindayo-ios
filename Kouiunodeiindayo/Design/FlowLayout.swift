import SwiftUI

/// 子を左から並べ、入りきらなければ次の行に送るレイアウト（タグのチップを折り返して並べる）。
/// 記録の詳細のタグの行と、タグの一覧のシートで使う。
struct FlowLayout: Layout {
    /// 横の間隔
    var spacing: CGFloat = Theme.chipSpacing
    /// 行と行の間隔
    var lineSpacing: CGFloat = Theme.chipSpacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // 同じ行の子は、縦の真ん中をそろえる
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    /// 1 行ぶん。入っている子の番号と、行の幅・高さ
    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 幅 `maxWidth` に入るように、子を行に分ける。1 つで幅を超える子は、その子だけで 1 行にする
    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, nextWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

#Preview("幅 375pt にチップ 8 個") {
    FlowLayout {
        ForEach([Tag.ramen, .gyoza, .karaage, .noodles, .riceDish, .fried, .chinese, .japanese], id: \.self) { tag in
            TagChipView(tag: tag, isAttached: true) {}
        }
        TagAddChipView(hasTags: true) {}
    }
    .padding(.horizontal, 16)
    .frame(width: 375)
    .background(Theme.background)
}
