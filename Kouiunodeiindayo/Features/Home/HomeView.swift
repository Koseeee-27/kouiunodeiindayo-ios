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
    @State private var isSettingsShown = false

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
        // ふだんの文字サイズでは、スクロールせずに1画面に収める（今日の一枚が残りの高さに合わせて縮む）。
        // 文字サイズが大きいなどで中身が入り切らないとき（今日の一枚は `todayPhotoMinHeight` で数える）だけ、スクロールする版に切り替える。
        // 下タブの分は `RootView` が空ける
        ViewThatFits(in: .vertical) {
            content(fillsHeight: true)
            ScrollView {
                content(fillsHeight: false)
            }
        }
        .background(Theme.background)
        // sheet で開くので、閉じてもホームの位置は残る
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
        }
        // `SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる
        .fullScreenCover(isPresented: $isSortShown) {
            SortView()
        }
        .sheet(isPresented: $isSettingsShown) {
            SettingsView()
        }
    }

    /// 1画面に収める版で、今日の一枚をこれより小さくしない（pt）。これを取れないときはスクロールする版にする
    private static let todayPhotoMinHeight: CGFloat = 200

    /// `fillsHeight` が true のときは、今日の一枚に残りの高さを渡し、余りは一番下に空ける
    private func content(fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // 仕分け待ちの帯の有無で位置が変わらないよう、帯より上に置く
            settingsButtonRow
            if !unsortedRecords.isEmpty {
                sortEntry
            }
            todaySection(fillsHeight: fillsHeight)
                // ほかの要素より先に、残りの高さを受け取る
                .layoutPriority(1)
            if !recentRecords.isEmpty {
                recentSection
            }
            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding()
    }

    /// 右上の設定のアイコン。ホームは `NavigationStack` を持たず `.toolbar` を使えないので、自前の行にする（見た目は仮）
    private var settingsButtonRow: some View {
        HStack {
            Spacer()
            Button {
                isSettingsShown = true
            } label: {
                Image(systemName: "gearshape")
                    .font(Theme.font(.title2))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定")
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

    private func todaySection(fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日の一枚")
                .font(Theme.font(.headline, bold: true))
            if let record = todayRecord {
                Button {
                    selectedRecord = record
                } label: {
                    // 3:4 の枠いっぱいに広げて切り抜く（横長の写真は左右が切れる）。大きさは横幅いっぱいが上限
                    RecordPhotoView(record: record, kind: .photo, showsFavoriteLabel: true)
                        .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("今日の一枚\(Self.favoriteSuffix(record))。記録の詳細を開く")
                // 1画面に収まるかを測るときは、最小の高さで測る（`ViewThatFits` は理想の大きさで比べる）
                .frame(
                    minHeight: fillsHeight ? Self.todayPhotoMinHeight : nil,
                    idealHeight: fillsHeight ? Self.todayPhotoMinHeight : nil
                )
                // 高さで決まって横幅より細くなったときは、左右の真ん中に置く
                .frame(maxWidth: .infinity)
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
                .font(Theme.font(.headline, bold: true))
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

/// 一番小さい機種（iPhone SE 第3世代。幅 375pt・高さ 667pt から上のステータスバー 20pt を除いた大きさ）で、
/// ふだんの文字サイズならスクロールせずに下タブの上まで収まるかを見る。下タブも入れるため `RootView` で出す
#Preview("SE 相当・仕分け待ちあり") {
    RootView(startTab: .home)
        .frame(width: 375, height: 647)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("SE 相当・文字サイズ XXX Large") {
    RootView(startTab: .home)
        .frame(width: 375, height: 647)
        .dynamicTypeSize(.xxxLarge)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
