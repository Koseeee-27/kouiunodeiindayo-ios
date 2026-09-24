import SwiftData
import SwiftUI

/// 仕分け済みの記録を新しい順に、サムネイルのグリッドで並べる。上に仕分け待ちの入口（枚数つき）を置く。
/// 要素と状態は `docs/screen-design.md` の「一覧」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。
struct RecordListView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue

    /// 仕分け済み（「なし」を含む）の新しい順
    @Query(
        filter: #Predicate<Record> { $0.genre != unsorted },
        sort: \Record.takenAt, order: .reverse
    )
    private var records: [Record]
    /// 枚数だけ使う
    @Query(filter: #Predicate<Record> { $0.genre == unsorted })
    private var unsortedRecords: [Record]

    /// 詳細を開いている記録
    @State private var selectedRecord: Record?
    @State private var isSortShown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !unsortedRecords.isEmpty {
                    sortEntry
                }
                if records.isEmpty {
                    Text("まだ記録がありません")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    grid
                }
            }
            .padding()
        }
        // #13 で記録を渡す形にする。仮の詳細には閉じるボタンが無いので、下に引いて閉じられる sheet にしておく
        .sheet(item: $selectedRecord) { _ in
            RecordDetailView()
        }
        // `SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる
        .fullScreenCover(isPresented: $isSortShown) {
            SortView()
        }
    }

    private var sortEntry: some View {
        Button {
            isSortShown = true
        } label: {
            HStack {
                Image(systemName: "tray.full")
                Text("仕分け待ち \(unsortedRecords.count) 枚")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("仕分け待ち \(unsortedRecords.count) 枚。仕分けを始める")
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(records, id: \.id) { record in
                Button {
                    selectedRecord = record
                } label: {
                    RecordPhotoView(record: record, kind: .thumbnail, showsFavoriteLabel: true)
                        .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(record.isFavorite ? "。うまい付き" : "")。記録の詳細を開く"
                )
            }
        }
    }
}

#Preview("記録あり・仕分け待ちあり") {
    RecordListView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("記録ゼロ") {
    RecordListView()
        .modelContainer(SampleData.makeContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
