import SwiftUI

/// 画面の下に出す自作のタブバー。左からカメラ／ホーム／一覧（`RootTab` の並び順）。
/// 標準の `TabView` の下タブは、タブ同士を指で滑らせて行き来できないため自作する（`docs/plans/root-tabs.plan.md`）。
/// 色・フォントは `Design/Theme.swift`（Issue #23）ができてから当てる。
struct RootTabBar: View {
    let selected: RootTab
    let onSelect: (RootTab) -> Void

    var body: some View {
        HStack(spacing: 32) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundStyle(style(isSelected: tab == selected))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        // glassEffect は見た目に関わる修飾子のあとに付ける（Apple の公式ドキュメントの注意）
        .glassEffect()
    }

    /// `.tint` と `.secondary` は型が違うので、`AnyShapeStyle` で揃えてから渡す。
    private func style(isSelected: Bool) -> AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach(RootTab.allCases, id: \.self) { tab in
            RootTabBar(selected: tab, onSelect: { _ in })
        }
    }
    .padding()
}
