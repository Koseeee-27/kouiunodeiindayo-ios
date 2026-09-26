import PhotosUI
import SwiftData
import SwiftUI

/// ホーム。今日の一枚を大きく出し、その下に最近の写真、上に仕分け待ちの入口（枚数つき）を置く。
/// 要素と状態は `docs/screen-design.md` の「ホーム」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。
/// 今日の一枚は今日撮った記録のうち一番新しい1枚、最近の写真は今日の一枚を除く新しい順の4枚。仕分け待ちはどちらにも出さない。
/// 右上の写真のアイコンから、アルバムの写真をまとめて取り込み（機能18。`PhotoImporter`）、取り込んだ写真だけの仕分けを開く。
struct HomeView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue
    private static let recentCount = 4

    /// 撮るボタン。カメラのカバーの出し方は `RootView` が持つ
    let onTakePhoto: () -> Void
    /// 取り込みの進み具合が変わったとき（終わったら nil）。`RootView` が、取り込み中の幕をページャーと下タブの上に重ねる
    let onImportProgressChange: (PhotoImportProgress?) -> Void

    /// 仕分け済みの新しい順。「今日」は `#Predicate` に書けないので、`body` で切り分ける
    @Query(
        filter: #Predicate<Record> { $0.genre != unsorted },
        sort: \Record.takenAt, order: .reverse
    )
    private var records: [Record]
    /// 枚数だけ使う
    @Query(filter: #Predicate<Record> { $0.genre == unsorted })
    private var unsortedRecords: [Record]

    /// 詳細を開いている記録の id。記録そのものではなく id で持ち、開くときに今の `@Query` から引き直す（詳細で消した記録を読まないように）
    @State private var selectedRecord: DetailTarget?

    /// 詳細を開くときに渡すもの（記録の id）。sheet の `item` にするため `Identifiable` にする
    private struct DetailTarget: Identifiable {
        let id: UUID
    }
    @State private var isSortShown = false
    @State private var isSettingsShown = false
    /// アルバムで選ばれた写真。受け取ったらすぐ空に戻す（同じ写真をもう一度選べるように）
    @State private var pickedItems: [PhotosPickerItem] = []
    /// 取り込み中の進み具合。幕は `RootView` が出す
    @State private var importProgress: PhotoImportProgress?
    /// 取り込みが終わり、取り込んだ写真だけの仕分けを出しているときの結果
    @State private var importResult: PhotoImportResult?
    /// 食事らしい写真が 0 枚だったときの結果。アラートに使う
    @State private var emptyImportResult: PhotoImportResult?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    /// 下タブの上端までの高さ。スクロールしない版で、最近の写真が下タブの裏に隠れないように下を空ける
    @Environment(\.tabBarInset) private var tabBarInset

    /// プレビュー「取り込み中」で使う、進み具合の代わり
    private let previewImportProgress: PhotoImportProgress?

    /// 引数の `importProgress` は `previewImportProgress` に入れる。プレビューで取り込み中の幕を見るためだけに渡す。
    init(
        onTakePhoto: @escaping () -> Void,
        onImportProgressChange: @escaping (PhotoImportProgress?) -> Void = { _ in },
        importProgress: PhotoImportProgress? = nil
    ) {
        self.onTakePhoto = onTakePhoto
        self.onImportProgressChange = onImportProgressChange
        previewImportProgress = importProgress
    }

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
        // ページャーは下タブの裏まで広がる。スクロールする版の下余白は `RootView` の `contentMargins` が、
        // スクロールしない版の下余白は `tabBarInset` で空ける
        ViewThatFits(in: .vertical) {
            content(fillsHeight: true)
                .padding(.bottom, tabBarInset)
            ScrollView {
                content(fillsHeight: false)
            }
        }
        .background(Theme.background)
        // sheet で開くので、閉じてもホームの位置は残る
        .sheet(item: $selectedRecord) { target in
            // 開いた記録が消えたとき（詳細で消して、閉じ終わるまで）は詳細を作らない
            if let initial = records.first(where: { $0.id == target.id }) {
                RecordDetailView(records: records, initial: initial)
            } else {
                Theme.background
            }
        }
        // `SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる
        .fullScreenCover(isPresented: $isSortShown) {
            SortView()
        }
        .sheet(isPresented: $isSettingsShown) {
            SettingsView()
        }
        .overlay {
            // ふだんの幕は `RootView` が出す。ホームだけのプレビューで見るときだけ、ここで出す
            if let previewImportProgress {
                PhotoImportingOverlayView(progress: previewImportProgress)
            }
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            pickedItems = []
            startImport(items)
        }
        .onChange(of: importProgress) { _, progress in
            onImportProgressChange(progress)
        }
        // 取り込んだ写真だけの仕分け。閉じ方は入口からの仕分けと同じ
        .fullScreenCover(item: $importResult) { result in
            SortView(importedIDs: result.importedIDs, importSummary: result)
        }
        .alert(
            emptyImportResult?.emptyAlertTitle ?? "",
            isPresented: Binding(
                get: { emptyImportResult != nil },
                set: { if !$0 { emptyImportResult = nil } }
            ),
            presenting: emptyImportResult
        ) { _ in
            Button("OK") {}
        } message: { result in
            Text(verbatim: result.emptyAlertMessage)
                .accessibilityLabel(Text(verbatim: result.emptyAlertAccessibilityLabel))
        }
    }

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    /// 選ばれた写真を 1 枚ずつ取り込む。終わったら、1 枚以上なら仕分けを開き、0 枚ならアラートを出す。
    /// 取り込み中は下タブもページのスワイプも止まる（`RootView`）。途中でアプリが終わっても、そこまでの写真は仕分け待ちに残る
    private func startImport(_ items: [PhotosPickerItem]) {
        guard PhotoImporter.shouldStart(selectedCount: items.count, isImporting: importProgress != nil) else { return }
        importProgress = PhotoImportProgress(done: 0, total: items.count)
        let runner = PhotoImportRunner.live(store: store)
        Task {
            // 選んだ直後は、ピッカーがまだ閉じる途中。1 枚だけだと取り込みがすぐ終わり、閉じきる前に仕分けのカバーを出すと
            // カバーの中身が上のセーフエリアにずれて ✕ が押せなくなる（シミュレータで確認）。閉じ終わるのを待ってから始める
            try? await Task.sleep(for: Self.pickerDismissDelay)
            let result = await runner.run(items) { done, total in
                importProgress = PhotoImportProgress(done: done, total: total)
            }
            importProgress = nil
            if result.importedIDs.isEmpty {
                emptyImportResult = result
            } else {
                importResult = result
            }
        }
    }

    /// ピッカーが閉じ終わるまで待つ時間
    private static let pickerDismissDelay: Duration = .milliseconds(600)

    /// 「今日の一枚」の見出しと写真の間、写真と「最近の写真」の見出しの間の最小の余白（pt）
    private static let todayPhotoGap: CGFloat = 12

    /// 1画面に収める版で、今日の一枚をこれより小さくしない（pt）。これを取れないときはスクロールする版にする
    private static let todayPhotoMinHeight: CGFloat = 200

    /// `fillsHeight` が true のときは、今日の一枚に残りの高さを渡す。余りは、今日の一枚と最近の写真の間に空ける（最近の写真が一番下）
    private func content(fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: Self.headerToContentSpacing) {
            // 仕分け待ちの吹き出しの有無で位置が変わらないよう、吹き出しより上に置く
            VStack(alignment: .leading, spacing: 4) {
                settingsButtonRow
                // タイトルと下の内容の区切り線（一覧と同じ）。画面の端まで伸ばすため、外側の余白のぶん外に広げる
                Rectangle()
                    .fill(Theme.line)
                    .frame(height: Theme.lineWidthThick)
                    .padding(.horizontal, -Self.contentPadding)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                if !unsortedRecords.isEmpty {
                    sortEntry
                        .padding(.bottom, 16)
                }
                // 残りの高さを全部受け取る。写真は「今日の一枚」と「最近の写真」の見出しの真ん中に置き、最近の写真は一番下に置く
                // （今日の一枚が無いときも同じ位置）
                todaySection(fillsHeight: fillsHeight)
                    .frame(maxHeight: fillsHeight ? .infinity : nil)
                    // ほかの要素より先に、残りの高さを受け取る
                    .layoutPriority(1)
                if !recentRecords.isEmpty {
                    recentSection
                }
            }
        }
        .padding(Self.contentPadding)
    }

    /// 区切り線と、その下の内容の間隔（一覧と同じ）
    private static let headerToContentSpacing: CGFloat = 23

    /// 画面の左右・上下の余白
    private static let contentPadding: CGFloat = 16

    /// 左上のタイトルロゴと右上の設定のアイコン。ホームは `NavigationStack` を持たず `.toolbar` を使えないので、自前の行にする（見た目は仮）
    private var settingsButtonRow: some View {
        HStack(spacing: 0) {
            TitleLogoView()
            Spacer()
            // アルバムから取り込む（機能18）。写真ライブラリの許可は要らない（選んだ写真だけが渡る）
            PhotosPicker(
                selection: $pickedItems,
                maxSelectionCount: PhotoImporter.maxSelectionCount,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                headerIcon("photo.on.rectangle")
            }
            .buttonStyle(.plain)
            // 幕の下になるが、読み上げなどから押されないよう、取り込み中は止める
            .disabled(importProgress != nil)
            .accessibilityLabel("アルバムから取り込む")
            Button {
                isSettingsShown = true
            } label: {
                headerIcon("gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定")
        }
    }

    /// 右上のアイコン。ロゴより小さく、目立たない色にする（押せる範囲は 44pt のまま）
    private func headerIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(Theme.font(.title3))
            .foregroundStyle(Theme.textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }

    private var sortEntry: some View {
        SortEntryBubbleView(count: unsortedRecords.count) {
            isSortShown = true
        }
    }

    private func todaySection(fillsHeight: Bool) -> some View {
        Group {
            if let record = todayRecord {
                // 見出しは、写真の左端にそろえる。写真が高さで決まって横幅より細いときは、見出しごと左右の真ん中に置く
                VStack(alignment: .leading, spacing: 0) {
                    todayHeading
                    // 写真の上下の余白。余りは上下に半分ずつ入る
                    Spacer(minLength: Self.todayPhotoGap)
                    Button {
                        selectedRecord = DetailTarget(id: record.id)
                    } label: {
                        // 3:4 の枠いっぱいに広げて切り抜く（横長の写真は左右が切れる）。大きさは横幅いっぱいが上限
                        RecordPhotoView(record: record, kind: .photo)
                            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
                            .photoFrame(.main)
                            // 「うまい」は、一覧・最近の写真と同じ、枠から少しはみ出す右肩下がりの形（枠のあとに重ねる）
                            .listFavoriteBadge(
                                isFavorite: record.isFavorite, relativeWidth: Theme.todayFavoriteBadgeWidthRatio)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("今日の一枚\(Self.favoriteSuffix(record))。記録の詳細を開く")
                    // 大きさは、デザインの画像の比率に合わせて、画面の横幅に対する割合で決める（高さは 3:4 で決まる）
                    .containerRelativeFrame(.horizontal) { length, _ in length * Theme.todayPhotoWidthRatio }
                    // 1画面に収まるかを測るときは、最小の高さで測る（`ViewThatFits` は理想の大きさで比べる）
                    .frame(
                        minHeight: fillsHeight ? Self.todayPhotoMinHeight : nil,
                        idealHeight: fillsHeight ? Self.todayPhotoMinHeight : nil
                    )
                    // 写真は余白より先に、高さを受け取る
                    .layoutPriority(1)
                    Spacer(minLength: Self.todayPhotoGap)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    todayHeading
                    // 言葉とボタンは、今日の一枚の写真が入る場所（見出しの下、残りの高さ）の真ん中に置く。
                    // 1画面に収まるかを測るときは、写真と同じ最小の高さで測る
                    VStack(spacing: 16) {
                        Text("今日はまだ撮っていません")
                        Button("撮る") {
                            onTakePhoto()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("カメラを開いて撮る")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(
                        minHeight: fillsHeight ? Self.todayPhotoMinHeight : nil,
                        idealHeight: fillsHeight ? Self.todayPhotoMinHeight : nil,
                        maxHeight: fillsHeight ? .infinity : nil
                    )
                    // スクロールする版では、残りの高さが決まらないので、上下に余白を取る
                    .padding(.vertical, fillsHeight ? 0 : 48)
                }
            }
        }
    }

    private var todayHeading: some View {
        Text("今日の一枚")
            .font(Theme.font(.headline, bold: true))
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
                        selectedRecord = DetailTarget(id: record.id)
                    } label: {
                        RecordPhotoView(record: record, kind: .thumbnail)
                            .aspectRatio(1, contentMode: .fit)
                            .photoFrame(.small)
                            // 「うまい」は、一覧と同じ、枠から少しはみ出す右肩下がりの形（枠のあとに重ねる）
                            .listFavoriteBadge(isFavorite: record.isFavorite)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(Self.favoriteSuffix(record))。記録の詳細を開く"
                    )
                    // はみ出した「うまい」が、右隣の写真の下に隠れないよう、お気に入りの写真を手前に描く
                    .zIndex(record.isFavorite ? 1 : 0)
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

#Preview("取り込み中") {
    HomeView(onTakePhoto: {}, importProgress: PhotoImportProgress(done: 3, total: 12))
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
