import OSLog
import SwiftData
import SwiftUI

/// 仕分け済みの記録を新しい順に、サムネイルのグリッドで並べる。上に仕分け待ちの入口（枚数つき）を置く。
/// 要素と状態は `docs/screen-design.md` の「一覧」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。
/// 上の欄から言葉で探せる（機能28）。キーボードの「検索」を押すと、言葉からタグ・うまい・時期を読み取って（`LocalSearchParser`）、
/// 合う記録だけに絞る（`RecordSearchFilter`）。端末の中で読み取れなかった言葉だけ、Worker に聞く（`WordSearchService`。M2）。
/// 絞り込みは端末の中だけで行い、記録は送らない（送るのは読み取れなかった言葉だけ）。
/// 上の行の右端の「選択」で選ぶモードに入り、写真をタップして選んで、まとめて消せる（機能11。#118）。
/// 選ぶモードの間は下タブの代わりに消すの操作を出すので、選ぶモードかどうかを `onSelectingChange` で `RootView` に伝える。
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

    /// 詳細を開いているもの（開いた記録と、開いた時点の並び）
    @State private var detailSelection: DetailSelection?
    @State private var isSortShown = false
    /// 検索の欄の言葉
    @State private var searchText = ""
    /// 絞り込みの条件。`nil` は絞り込んでいない
    @State private var condition: SearchCondition?
    /// 読み取れなかった・通信できなかったときの知らせ。一覧はそのまま
    @State private var message: String?
    /// 端末で読み取れなかった言葉を Worker に聞いている間（M2）。新しく探す・やめるときは取り消す
    @State private var workerSearch: Task<Void, Never>?
    /// Worker に聞いている語（聞いていないときは nil）。欄を書き換えたかを見るため
    @State private var workerQuery: String?
    @Environment(\.wordSearchService) private var wordSearchService
    @FocusState private var isSearchFocused: Bool
    /// 選ぶモード（まとめて消す）
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var isDeleteConfirmationShown = false
    @State private var isDeleteFailureShown = false
    /// 写真アプリに保存している間は、ボタンを押せなくする
    @State private var isSavingToPhotos = false
    /// 写真アプリに保存した結果の知らせ
    @State private var saveMessage: String?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    /// 画面の下のセーフエリア（`RootView` が入れる）。消すの操作を下タブと同じ位置に出すのに使う。`nil` はプレビューなど `RootView` の外
    @Environment(\.rootBottomSafeArea) private var rootBottomSafeArea
    /// 詳細を開くときに渡すもの。開いた記録と、開いた時点の並び（記録の id）を 1 つにまとめて sheet の `item` にする
    /// （別々の `@State` にすると、sheet の中身を作るときに並びがまだ空のまま読まれ、詳細が 1 件だけになった）。
    /// 詳細で「うまい」などを変えて絞り込みから外れても、開いている詳細のページが飛ばないように、開いたときの並びを渡す。
    /// 開いた記録も並びも、記録そのものではなく id で持ち、渡すときに今の `@Query` から引き直す（詳細で消した記録を読まないように）
    private struct DetailSelection: Identifiable {
        let recordID: UUID
        let ids: [UUID]
        var id: UUID { recordID }
    }

    /// 今の `@Query`（絞る前）の記録を id で引く表
    private var recordsByID: [UUID: Record] {
        Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    /// 時期で絞るときの「今」。日付が変わったとき・アプリに戻ったとき・探したときに取り直す
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase

    /// プレビューで、欄に言葉を入れて探した状態を見るための言葉。開いたときに一度だけ探す
    private let previewSearchText: String?
    /// プレビューで、選ぶモードを見るためのもの。`nil` は選ぶモードにしない。数は、先頭から選んでおく件数
    private let previewSelectedCount: Int?
    /// プレビューで、消す確認を開いた状態を見る
    private let previewShowsDeleteConfirmation: Bool
    private let onSelectingChange: (Bool) -> Void

    /// 引数の `searchText`・`selectedCount`・`showsDeleteConfirmation` は、プレビューで状態を見るためだけに渡す
    init(
        searchText: String? = nil,
        selectedCount: Int? = nil,
        showsDeleteConfirmation: Bool = false,
        onSelectingChange: @escaping (Bool) -> Void = { _ in }
    ) {
        previewSearchText = searchText
        previewSelectedCount = selectedCount
        previewShowsDeleteConfirmation = showsDeleteConfirmation
        self.onSelectingChange = onSelectingChange
    }

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    /// 画面に出す記録。絞り込み中は、条件に合うものだけ（並びは新しい順のまま）
    private var displayed: [Record] {
        condition.map { RecordSearchFilter.filter(records, by: $0, now: now) } ?? records
    }

    var body: some View {
        ScrollView {
            // 区切り線を画面の端まで伸ばすため、余白は線ではなく、タイトルと中身の側に付ける
            VStack(alignment: .leading, spacing: Self.headerToContentSpacing) {
                // ロゴと区切り線は、近づけて1組にする
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        TitleLogoView()
                        Spacer(minLength: 8)
                        selectButton
                    }
                    .padding(.horizontal)
                    // タイトルと下の内容の区切り線
                    Rectangle()
                        .fill(Theme.line)
                        .frame(height: Theme.lineWidthThick)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 16) {
                    if isSelecting {
                        selectionBar
                    }
                    // 選ぶモードの間は、欄と仕分け待ちの入口を押せなくする（見た目は残す。押すと選ぶ操作と混ざるため）
                    searchField
                        .disabled(isSelecting)
                    if let condition {
                        // 選ぶモードの間は、条件のチップと「やめる」も押せなくする（欄と同じ。絞り込みが変わると選んだ記録と混ざるため）
                        conditionRow(condition)
                            .disabled(isSelecting)
                    }
                    if workerSearch != nil {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("読み取っています…")
                        }
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                    } else if let message {
                        Text(message)
                            .font(Theme.font(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    // 絞り込み中は、結果と入口が混ざらないよう、仕分け待ちの入口を隠す
                    if !unsortedRecords.isEmpty && condition == nil {
                        sortEntry
                            .disabled(isSelecting)
                    }
                    // 絞り込み中を先に見る（仕分け済みが 0 件のときも「合う記録がありません」とやめるボタンを出す）
                    if condition != nil && displayed.isEmpty {
                        noMatchView
                    } else if records.isEmpty {
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
        .overlay(alignment: .bottom) {
            if isSelecting {
                actionBar
            }
        }
        // 確認の文に件数と「写真も消えます」を必ず出す（取り消しは無い）。詳細の 1 件の確認と同じく `alert` にする
        .alert("\(selectedIDs.count) 件の記録を消しますか？", isPresented: $isDeleteConfirmationShown) {
            Button("消す", role: .destructive) {
                deleteSelected()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("写真も消えます")
        }
        .alert("消せませんでした", isPresented: $isDeleteFailureShown) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            saveMessage ?? "", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: isSelecting) { _, selecting in
            // 選んでいる間に結果が届いて一覧が変わり、選んだ写真が外れないように、聞いている途中の検索はやめる
            if selecting {
                cancelWorkerSearch()
            }
            onSelectingChange(selecting)
        }
        // 絞り込みが変わった・記録が消えたときは、画面に無い記録を選んだままにしない
        .onChange(of: displayed.map(\.id)) { _, ids in
            selectedIDs.formIntersection(ids)
        }
        // sheet で開くので、閉じても一覧のスクロール位置は残る
        .sheet(item: $detailSelection) { selection in
            // 開いた記録と並びを、今の `@Query` から引き直す。消えた記録だけが並びから抜ける。
            // 開いた記録が消えたとき（詳細で消して、閉じ終わるまで）は詳細を作らない
            let byID = recordsByID
            if let initial = byID[selection.recordID] {
                // 絞り込み中は、絞り込んだ中で左右にめくる（開いた時点の並び）
                RecordDetailView(records: selection.ids.compactMap { byID[$0] }, initial: initial)
            } else {
                Theme.background
            }
        }
        // `SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる
        .fullScreenCover(isPresented: $isSortShown) {
            SortView()
        }
        // 欄を手で空にしたら、絞り込みもやめる（✕ が消えて戻す手段が見えなくならないように）。キーボードは閉じない
        .onChange(of: searchText) { _, text in
            if text.isEmpty {
                cancelWorkerSearch()
                condition = nil
                message = nil
            } else if let workerQuery, !WordSearchFlow.shouldApply(searchedQuery: workerQuery, currentText: text) {
                // Worker に聞いている間に書き換えたら、古い語の問い合わせはやめる（一覧はそのまま）
                cancelWorkerSearch()
            }
        }
        .onDisappear {
            cancelWorkerSearch()
        }
        // 「今日」「今週」「今月」で絞ったまま日付をまたいでも、古い結果が残らないように取り直す
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                now = .now
            }
        }
        .onAppear {
            if let previewSearchText {
                searchText = previewSearchText
                search()
            }
            if let previewSelectedCount {
                isSelecting = true
                selectedIDs = Set(displayed.prefix(previewSelectedCount).map(\.id))
                isDeleteConfirmationShown = previewShowsDeleteConfirmation
            }
        }
    }

    // MARK: 選ぶモード（まとめて消す）

    /// 上の行の右端。選ぶモードでないときは「選択」、選ぶモードのときは「キャンセル」。並べる記録が無いときは出さない
    @ViewBuilder
    private var selectButton: some View {
        if isSelecting {
            Button("キャンセル") {
                endSelecting()
            }
            .buttonStyle(.plain)
            .font(Theme.font(.body))
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
        } else if !displayed.isEmpty {
            Button("選択") {
                isSearchFocused = false
                isSelecting = true
            }
            .buttonStyle(.plain)
            .font(Theme.font(.body))
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
            .accessibilityHint("記録を選んで、まとめて消せます")
        }
    }

    /// 選んだ件数と「すべて選択」。絞り込み中は、絞り込んだ結果だけを選ぶ
    private var selectionBar: some View {
        let allSelected = !displayed.isEmpty && displayed.allSatisfy { selectedIDs.contains($0.id) }
        return HStack {
            Text("\(selectedIDs.count) 件を選択")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Button(allSelected ? "選択を解除" : "すべて選択") {
                if allSelected {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = Set(displayed.map(\.id))
                }
            }
            .buttonStyle(.plain)
            .font(Theme.font(.subheadline))
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
        }
    }

    /// 下タブの代わりに出す操作のバー（「保存」と「消す」）。下タブと同じ位置・同じガラスの見た目・同じ高さにする
    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton("保存", systemImage: "square.and.arrow.down", tint: Theme.textPrimary) {
                saveSelectedToPhotos()
            }
            .disabled(selectedIDs.isEmpty || isSavingToPhotos)
            .accessibilityLabel("選んだ記録の写真を写真アプリに保存する")
            actionButton("消す", systemImage: "trash", tint: Theme.accent) {
                isDeleteConfirmationShown = true
            }
            .disabled(selectedIDs.isEmpty || isSavingToPhotos)
            .accessibilityLabel("選んだ記録を消す")
        }
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        // `RootView` の中では、ページャーが画面の下まで広がっているので、下タブと同じくセーフエリアの上に置く
        .padding(.bottom, rootBottomSafeArea ?? 0)
        .ignoresSafeArea(edges: rootBottomSafeArea == nil ? [] : .bottom)
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(Theme.font(.caption2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedIDs.isEmpty ? Theme.textSecondary : tint)
    }

    /// 選んだ記録の写真を写真アプリに保存する（設定のスイッチとは関係なく保存する）。1 枚でも保存できたら選ぶモードを抜ける
    private func saveSelectedToPhotos() {
        let urls = displayed.filter { selectedIDs.contains($0.id) }.map { store.photoURL(fileName: $0.photoFileName) }
        isSavingToPhotos = true
        Task {
            let outcome = await PhotoLibrarySaver.save(fileURLs: urls)
            isSavingToPhotos = false
            if case .finished(let saved, _) = outcome, saved > 0 {
                endSelecting()
            }
            saveMessage = PhotoLibrarySaver.message(for: outcome)
        }
    }

    private func toggleSelection(_ record: Record) {
        if selectedIDs.contains(record.id) {
            selectedIDs.remove(record.id)
        } else {
            selectedIDs.insert(record.id)
        }
    }

    private func endSelecting() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    /// 選んだ記録を消す。選ぶモードの間は詳細を開けないので、消した記録の詳細が開いていることは無い
    private func deleteSelected() {
        let selected = displayed.filter { selectedIDs.contains($0.id) }
        do {
            try store.delete(selected)
            endSelecting()
        } catch {
            isDeleteFailureShown = true
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

    /// 読み取った条件のチップと「やめる」。欄のすぐ下に、何で絞っているかを見せる（読み取りの取り違えに気づいて言い直せるように）。
    /// チップの − で、その条件だけ外して絞り直す
    private func conditionRow(_ condition: SearchCondition) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // チップは押せる範囲を上下に広げているので、行の間は空けない（見た目の間はその分で足りる）
            FlowLayout(lineSpacing: 0) {
                if let tag = condition.tag {
                    TagChipView(tag: tag, isAttached: true) {
                        remove { $0.tag = nil }
                    }
                }
                if condition.favoriteOnly {
                    TagChipView(title: "うまい", accessibilityLabel: "うまい", isAttached: true) {
                        remove { $0.favoriteOnly = false }
                    }
                }
                if let period = condition.period {
                    TagChipView(title: period.title, accessibilityLabel: "時期 \(period.title)", isAttached: true) {
                        remove { $0.period = nil }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("やめる") {
                clear()
            }
            .font(Theme.font(.subheadline, bold: true))
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: Theme.minTapHeight)
            .accessibilityLabel("絞り込みをやめる")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("絞り込みの条件")
    }

    /// 条件を 1 つ外して絞り直す。全部外れたら、やめるのと同じ
    private func remove(_ change: (inout SearchCondition) -> Void) {
        guard var next = condition else { return }
        // Worker に聞いている途中なら、あとから届いた結果で上書きしないよう捨てる
        cancelWorkerSearch()
        change(&next)
        if next.isEmpty {
            clear()
        } else {
            condition = next
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

    /// 言葉から条件を読み取って絞る。端末の中で読み取れたら通信せずに絞る。読み取れなかったときだけ Worker に聞く（M2）。
    /// Worker も読み取れない・通信できないときは、知らせを出して一覧はそのまま
    private func search() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            clear()
            return
        }
        now = .now
        cancelWorkerSearch()
        let parsed = LocalSearchParser.parse(text)
        guard parsed.isEmpty else {
            show(parsed, message: nil)
            return
        }
        guard !WordSearchFlow.isTooLong(text) else {
            show(condition, message: WordSearchFlow.tooLongMessage)
            return
        }
        // 聞いている間は、前の結果（絞り込み中なら、その一覧）をそのまま出しておく
        message = nil
        let service = wordSearchService
        workerQuery = text
        workerSearch = Task {
            let result: SearchCondition?
            do {
                result = try await service.search(text)
            } catch {
                // 言葉はログに出さない（ADR 0006）。種類だけ
                Self.logger.notice("言葉で探す：Worker に聞けなかった（\(String(describing: type(of: error)))）")
                result = nil
            }
            // 取り消された（新しく探した・やめた・欄を書き換えた）なら、あとから届いた結果で上書きしない
            guard !Task.isCancelled, WordSearchFlow.shouldApply(searchedQuery: text, currentText: searchText) else {
                return
            }
            workerSearch = nil
            workerQuery = nil
            let outcome = WordSearchFlow.outcome(result: result, previous: condition)
            show(outcome.condition, message: outcome.message)
        }
    }

    private static let logger = Logger(category: "RecordListView")

    private func cancelWorkerSearch() {
        workerSearch?.cancel()
        workerSearch = nil
        workerQuery = nil
    }

    /// 探した結果を出す。`condition` が `nil` なら絞り込みをやめる
    private func show(_ newCondition: SearchCondition?, message newMessage: String?) {
        condition = newCondition
        message = newMessage
        // 結果は画面が変わるだけで読み上げの位置は欄に残るので、件数か知らせを読み上げる
        let announcement: String
        if let message {
            announcement = message
        } else if displayed.isEmpty {
            announcement = "合う記録がありません"
        } else {
            announcement = "\(displayed.count) 件"
        }
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// 絞り込みをやめて、元の一覧に戻す
    private func clear() {
        cancelWorkerSearch()
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
        let isSelected = selectedIDs.contains(record.id)
        let date =
            "\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真\(record.isFavorite ? "。うまい付き" : "")"
        return Button {
            // 選ぶモードの間は、押すと選ぶ・外す（詳細は開かない）
            if isSelecting {
                toggleSelection(record)
            } else {
                detailSelection = DetailSelection(recordID: record.id, ids: displayed.map(\.id))
            }
        } label: {
            RecordPhotoView(record: record, kind: .thumbnail)
                .aspectRatio(1, contentMode: .fit)
                // 選んだ写真は少し暗くする
                .overlay {
                    if isSelecting && isSelected {
                        Color.black.opacity(Self.selectedDimOpacity)
                    }
                }
                .photoFrame(.small)
                // 選ぶ印は右下（「うまい」のハンコは右上なので重ならない）
                .overlay(alignment: .bottomTrailing) {
                    if isSelecting {
                        selectionMark(isSelected: isSelected)
                            .padding(Self.selectionMarkPadding)
                    }
                }
                // 「うまい」は、枠の切り抜きの外に重ねる（枠から少しはみ出させる）
                .listFavoriteBadge(isFavorite: record.isFavorite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelecting ? "\(date)。\(isSelected ? "選択中" : "選択されていません")" : "\(date)。記録の詳細を開く")
        .accessibilityHint(isSelecting ? (isSelected ? "押すと外します" : "押すと選びます") : "")
        .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
        // はみ出した「うまい」が、右隣の写真の下に隠れないよう、お気に入りの写真を手前に描く
        .zIndex(record.isFavorite ? 1 : 0)
    }

    /// 選ぶ印。選んでいないときは白い丸の枠、選ぶと墨の丸に白いチェック
    private func selectionMark(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(Theme.textPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: Self.selectionMarkSize * 0.5, weight: .bold))
                    .foregroundStyle(Theme.onMain)
            } else {
                // 明るい写真の上でも見えるよう、薄い影を付ける
                Circle().fill(.black.opacity(0.15))
            }
            Circle().strokeBorder(.white, lineWidth: 2)
        }
        .frame(width: Self.selectionMarkSize, height: Self.selectionMarkSize)
        .shadow(color: .black.opacity(0.3), radius: 1)
        .accessibilityHidden(true)
    }

    /// 選ぶ印の大きさと、写真の角からの隙間
    private static let selectionMarkSize: CGFloat = 24
    private static let selectionMarkPadding: CGFloat = 6
    /// 選んだ写真に重ねる黒の濃さ
    private static let selectedDimOpacity: Double = 0.3
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

#Preview("絞り込み中（ラーメン・うまい・今月より前）") {
    RecordListView(searchText: "今月より前のうまいラーメン")
        .modelContainer(RecordListPreviewData.makeEarlierRamenContainer())
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
        .environment(\.wordSearchService, WordSearchMock.nothing)
}

// 端末で読み取れない言葉を Worker に聞く（M2）。モックが、うまいラーメンと読んだことにする
#Preview("Worker に聞いて絞る") {
    RecordListView(searchText: "こってりしたもの")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.wordSearchService, WordSearchMock.ramen)
}

#Preview("Worker に聞いている") {
    RecordListView(searchText: "こってりしたもの")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.wordSearchService, WordSearchMock(result: nil, delay: .seconds(60)))
}

#Preview("通信できない") {
    RecordListView(searchText: "こってりしたもの")
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.wordSearchService, WordSearchMock.disabled)
}

#Preview("SE 相当・文字サイズ XXX Large") {
    RecordListView(searchText: "今月より前のうまいラーメン")
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xxxLarge)
        .modelContainer(RecordListPreviewData.makeEarlierRamenContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("選ぶモード・何も選んでいない") {
    RecordListView(selectedCount: 0)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("選ぶモード・2 件選んだ") {
    RecordListView(selectedCount: 2)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("選ぶモード・消す確認") {
    RecordListView(selectedCount: 2, showsDeleteConfirmation: true)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("選ぶモード・絞り込み中（うまい）・すべて選択") {
    RecordListView(searchText: "うまい", selectedCount: 99)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("選ぶモード・SE 相当・文字サイズ XXX Large") {
    RecordListView(selectedCount: 1)
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

/// 一覧のプレビュー用のデータ
enum RecordListPreviewData {
    /// サンプルに、先月以前の「うまい」のラーメンを 1 件足したもの（「今月より前」で当たる記録を見るため）
    static func makeEarlierRamenContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let takenAt = Calendar.current.date(byAdding: .day, value: -45, to: .now) ?? .now
        // プレビュー用なので、作れなければ落として気づく
        let record = try! store.add(image: SampleData.makeImage(color: .systemBrown), takenAt: takenAt)
        store.setGenre(.food, for: record)
        store.toggleFavorite(record)
        store.setTags([.ramen], for: record)
        return container
    }
}
