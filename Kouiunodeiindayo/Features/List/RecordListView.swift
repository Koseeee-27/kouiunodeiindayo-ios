import SwiftData
import SwiftUI

/// 仕分け済みの記録を新しい順に、サムネイルのグリッドで並べる。上に仕分け待ちの入口（枚数つき）を置く。
/// 要素と状態は `docs/screen-design.md` の「一覧」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。
/// 上の欄から言葉で探せる（機能28）。キーボードの「検索」を押すと、言葉からタグ・うまい・時期を読み取って（`LocalSearchParser`）、
/// 合う記録だけに絞る（`RecordSearchFilter`）。絞り込みは端末の中だけで行い、記録は送らない。
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
    /// 検索の欄の言葉
    @State private var searchText = ""
    /// 絞り込みの条件。`nil` は絞り込んでいない
    @State private var condition: SearchCondition?
    /// 読み取れなかったときの知らせ。一覧はそのまま
    @State private var message: String?
    @FocusState private var isSearchFocused: Bool

    /// プレビューで、欄に言葉を入れて探した状態を見るための言葉。開いたときに一度だけ探す
    private let previewSearchText: String?

    /// 引数の `searchText` は、プレビューで探した状態を見るためだけに渡す
    init(searchText: String? = nil) {
        previewSearchText = searchText
    }

    /// 画面に出す記録。絞り込み中は、条件に合うものだけ（並びは新しい順のまま）
    private var displayed: [Record] {
        condition.map { RecordSearchFilter.filter(records, by: $0) } ?? records
    }

    var body: some View {
        ScrollView {
            // 区切り線を画面の端まで伸ばすため、余白は線ではなく、タイトルと中身の側に付ける
            VStack(alignment: .leading, spacing: Self.headerToContentSpacing) {
                // ロゴと区切り線は、近づけて1組にする
                VStack(alignment: .leading, spacing: 4) {
                    TitleLogoView()
                        .padding(.horizontal)
                    // タイトルと下の内容の区切り線
                    Rectangle()
                        .fill(Theme.line)
                        .frame(height: Theme.lineWidthThick)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 16) {
                    searchField
                    if let message {
                        Text(message)
                            .font(Theme.font(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    // 絞り込み中は、結果と入口が混ざらないよう、仕分け待ちの入口を隠す
                    if !unsortedRecords.isEmpty && condition == nil {
                        sortEntry
                    }
                    if records.isEmpty {
                        Text("まだ記録がありません")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if displayed.isEmpty {
                        noMatchView
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
            // 絞り込み中は、絞り込んだ中で左右にめくる
            RecordDetailView(records: displayed, initial: record)
        }
        // `SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる
        .fullScreenCover(isPresented: $isSortShown) {
            SortView()
        }
        .onAppear {
            if let previewSearchText {
                searchText = previewSearchText
                search()
            }
        }
    }

    // MARK: 言葉で探す

    /// 検索の欄。いつも出しておき、一覧と一緒にスクロールする。キーボードの「検索」を押したときに探す（1 文字ごとには探さない）
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("ラーメン、うまい、今月 など", text: $searchText)
                .font(Theme.font(.body))
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit { search() }
                .accessibilityLabel("言葉で探す")
            if !searchText.isEmpty {
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: Theme.minTapHeight, minHeight: Theme.minTapHeight)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("絞り込みをやめる")
            }
        }
        .padding(.leading, 12)
        .frame(minHeight: Theme.minTapHeight)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadiusSmall))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .strokeBorder(Theme.line, lineWidth: Theme.lineWidthThin)
        }
    }

    /// 合う記録が無いとき
    private var noMatchView: some View {
        VStack(spacing: 12) {
            Text("合う記録がありません")
            Button("絞り込みをやめる") {
                clear()
            }
            .buttonStyle(.bordered)
            .tint(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    /// 言葉から条件を読み取って絞る。1 つも読み取れなければ、知らせを出して一覧はそのまま
    private func search() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            clear()
            return
        }
        let parsed = LocalSearchParser.parse(text)
        if parsed.isEmpty {
            condition = nil
            message = "条件を読み取れませんでした。タグの名前や『うまい』『今月』で探せます"
        } else {
            condition = parsed
            message = nil
        }
    }

    /// 絞り込みをやめて、元の一覧に戻す
    private func clear() {
        searchText = ""
        condition = nil
        message = nil
        isSearchFocused = false
    }

    private var sortEntry: some View {
        SortEntryBubbleView(count: unsortedRecords.count) {
            isSortShown = true
        }
    }

    /// 区切り線と、その下の内容の間隔（ホームと同じ）
    private static let headerToContentSpacing: CGFloat = 23
    /// 写真どうしの隙間（上下左右とも同じ）
    private static let photoSpacing: CGFloat = 6
    /// 月と月の隙間。写真どうしの隙間より少し広くする
    private static let monthSpacing: CGFloat = 20

    /// 新しい順の記録を、年と月ごとにまとめる（並びは保ったまま）
    private var months: [(month: DateComponents, records: [Record])] {
        var result: [(month: DateComponents, records: [Record])] = []
        for record in displayed {
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
            RecordPhotoView(record: record, kind: .thumbnail)
                .aspectRatio(1, contentMode: .fit)
                .photoFrame(.small)
                // 「うまい」は、枠の切り抜きの外に重ねる（枠から少しはみ出させる）
                .listFavoriteBadge(isFavorite: record.isFavorite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(record.isFavorite ? "。うまい付き" : "")。記録の詳細を開く"
        )
        // はみ出した「うまい」が、右隣の写真の下に隠れないよう、お気に入りの写真を手前に描く
        .zIndex(record.isFavorite ? 1 : 0)
    }
}

#Preview("記録あり・仕分け待ちあり") {
    RecordListView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("検索の欄（空）・仕分け待ちなし") {
    RecordListView()
        .modelContainer(HomePreviewData.makeNoUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("絞り込み中（ラーメン）") {
    RecordListView(searchText: "ラーメン")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("合う記録が無い") {
    RecordListView(searchText: "寿司")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("読み取れなかった") {
    RecordListView(searchText: "こんにちは")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("SE 相当・文字サイズ XXX Large") {
    RecordListView(searchText: "ラーメン")
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xxxLarge)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("記録ゼロ") {
    RecordListView()
        .modelContainer(SampleData.makeContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
