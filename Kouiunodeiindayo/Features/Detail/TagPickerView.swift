import SwiftData
import SwiftUI

/// タグの一覧から足す・外す（機能27）。記録の詳細の「＋ タグ」からシートで開く。押した時点で保存される（保存ボタンは無い）。
/// 種類（料理・大分類・系統）ごとに見出しを付け、`Tag.allCases` の順に並べる。付いているタグは − つき、付いていないタグは点線と ＋。
/// 料理のタグを足しても、大分類・系統は自動では足さない（`docs/data-model.md` の「タグの値」）。
struct TagPickerView: View {
    let record: Record

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(TagKind.allCases, id: \.self) { kind in
                        section(kind)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // 押した時点で保存済みなので、閉じるだけ
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func section(_ kind: TagKind) -> some View {
        let attached = Set(record.tagValues)
        return VStack(alignment: .leading, spacing: 8) {
            Text(kind.title)
                .font(Theme.font(.headline, bold: true))
                .accessibilityAddTraits(.isHeader)
            FlowLayout {
                ForEach(Tag.tags(of: kind), id: \.self) { tag in
                    TagChipView(tag: tag, isAttached: attached.contains(tag)) {
                        store.setTags(TagEditing.toggled(tag, in: record.tagValues), for: record)
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

#Preview("タグが 3 個付いた記録") {
    let container = SampleData.makePreviewContainer()
    // サンプルのラーメンの記録（ラーメン・麺類・中華）。プレビュー用なので、無ければ落として気づく
    let records = try! container.mainContext.fetch(FetchDescriptor<Record>())
    let record = records.first { $0.tags.contains("ramen") }!
    // シートで出すと、静止画がシートの出る前の瞬間になるので、中身をそのまま出す
    TagPickerView(record: record)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}
