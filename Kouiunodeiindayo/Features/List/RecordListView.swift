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
            // 区切り線を画面の端まで伸ばすため、余白は線ではなく、タイトルと中身の側に付ける
            VStack(alignment: .leading, spacing: 16) {
                Text("こういうのでいいんだよ")
                    .font(Theme.font(.title2, bold: true))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal)
                // タイトルと下の内容の区切り線
                Rectangle()
                    .fill(Theme.line)
                    .frame(height: Theme.lineWidthThick)
                    .accessibilityHidden(true)
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
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        // sheet で開くので、閉じても一覧のスクロール位置は残る
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
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

    /// 写真どうしの隙間（上下左右とも同じ）
    private static let photoSpacing: CGFloat = 6
    /// 月と月の隙間。写真どうしの隙間より少し広くする
    private static let monthSpacing: CGFloat = 20

    /// 新しい順の記録を、年と月ごとにまとめる（並びは保ったまま）
    private var months: [(month: DateComponents, records: [Record])] {
        var result: [(month: DateComponents, records: [Record])] = []
        for record in records {
            let month = Calendar.current.dateComponents([.year, .month], from: record.takenAt)
            if result.last?.month == month {
                result[result.count - 1].records.append(record)
            } else {
                result.append((month, [record]))
            }
        }
        return result
    }

    private var grid: some View {
        LazyVStack(alignment: .leading, spacing: Self.monthSpacing) {
            ForEach(months, id: \.month) { section in
                VStack(alignment: .leading, spacing: Self.photoSpacing) {
                    // 数字をそのまま補間すると「2,026」と桁区切りが入るので、文字列にしてから渡す
                    Text(verbatim: "\(section.month.year ?? 0)年\(section.month.month ?? 0)月")
                        .font(Theme.font(.headline, bold: true))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, Self.photoSpacing)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Self.photoSpacing), count: 3),
                        spacing: Self.photoSpacing
                    ) {
                        ForEach(section.records, id: \.id) { record in
                            photoButton(record)
                        }
                    }
                }
            }
        }
    }

    private func photoButton(_ record: Record) -> some View {
        Button {
            selectedRecord = record
        } label: {
            RecordPhotoView(record: record, kind: .thumbnail, showsFavoriteLabel: true)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Rectangle().stroke(Theme.line, lineWidth: Theme.lineWidthThin))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(record.isFavorite ? "。うまい付き" : "")。記録の詳細を開く"
        )
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
