import SwiftData
import SwiftUI

/// ホーム。今日の一枚を大きく出し、その下に最近の写真、上に仕分け待ちの入口（枚数つき）を置く。
/// 要素と状態は `docs/screen-design.md` の「ホーム」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。
/// 今日の一枚は今日撮った記録のうち一番新しい1枚、最近の写真は今日の一枚を除く新しい順の4枚。仕分け待ちはどちらにも出さない。
struct HomeView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue
    private static let recentCount = 4

    /// 撮るボタン。カメラのカバーの出し方は `RootView` が持つ
    let onTakePhoto: () -> Void

    /// 仕分け済みの新しい順。「今日」は `#Predicate` に書けないので、`body` で切り分ける
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

    /// 今日撮った記録のうち一番新しい1枚（新しい順なので、今日の最初の1件）。
    /// 先頭だけを見ると、日付を未来に直した記録（#13）があるとき今日の記録が隠れるので、今日の記録を探す。
    /// 日付をまたいでも再描画されるまでは変わらない（`docs/rules/swift.md` の注意どおり許容する）
    private var todayRecord: Record? {
        records.first { Calendar.current.isDateInToday($0.takenAt) }
    }

    /// 今日の一枚と同じ写真が2回出ないよう、今日の一枚を除く
    private var recentRecords: [Record] {
        let todayID = todayRecord?.id
        return Array(records.lazy.filter { $0.id != todayID }.prefix(Self.recentCount))
    }

    var body: some View {
        // 文字サイズ最大や小さい画面で下が切れないよう、スクロールできるようにする（下タブの分は `RootView` が空ける）
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !unsortedRecords.isEmpty {
                    sortEntry
                }
                todaySection
                if !recentRecords.isEmpty {
                    recentSection
                }
            }
            .padding()
        }
        // #13 で記録を渡す形にする。開き方（sheet か fullScreenCover か）も #13 で決めてよい。
        // 仮の詳細には閉じるボタンが無いので、下に引いて閉じられる sheet にしておく
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

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日の一枚")
                .font(.headline)
            if let record = todayRecord {
                Button {
                    selectedRecord = record
                } label: {
                    // 大きさは仮。#23 で見直す
                    RecordPhotoView(record: record, kind: .photo, showsFavoriteLabel: true)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("今日の一枚\(Self.favoriteSuffix(record))。記録の詳細を開く")
            } else {
                VStack(spacing: 16) {
                    Text("今日はまだ撮っていません")
                    Button("撮る") {
                        onTakePhoto()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("カメラを開いて撮る")
                }
                .frame(maxWidth: .infinity)
                // 写真の代わりの場所だと分かるよう、上下に余白を取る
                .padding(.vertical, 48)
            }
        }
    }

    /// 「うまい」のラベルは読み上げから隠しているので、ボタンの読み上げに足す
    private static func favoriteSuffix(_ record: Record) -> String {
        record.isFavorite ? "。うまい付き" : ""
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近の写真")
                .font(.headline)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: Self.recentCount),
                spacing: 8
            ) {
                ForEach(recentRecords, id: \.id) { record in
                    Button {
                        selectedRecord = record
                    } label: {
                        RecordPhotoView(record: record, kind: .thumbnail, showsFavoriteLabel: true)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(Self.favoriteSuffix(record))。記録の詳細を開く"
                    )
                }
            }
        }
    }
}

#Preview("今日の一枚あり・仕分け待ちあり") {
    HomeView(onTakePhoto: {})
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("今日の一枚あり・仕分け待ちなし") {
    HomeView(onTakePhoto: {})
        .modelContainer(HomePreviewData.makeNoUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("今日まだ撮っていない") {
    HomeView(onTakePhoto: {})
        .modelContainer(HomePreviewData.makeNoTodayContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("記録ゼロ") {
    HomeView(onTakePhoto: {})
        .modelContainer(SampleData.makeContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("記録が多い") {
    HomeView(onTakePhoto: {})
        .modelContainer(HomePreviewData.makeManyContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
