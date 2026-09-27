import SwiftData
import SwiftUI

/// 仕分け。写真のカードを4方向にスワイプ（またはラベルを押す）してジャンルを付け、「う、うまい」でお気に入りを付け外しする。
/// 要素と操作は `docs/screen-design.md` の「仕分け」、スワイプを自作する理由は `docs/adr/0005-swipe-ui.md` が正。
/// 開き方は3つ。下タブには載らない。
/// - `recordID` なし：ホーム・一覧の仕分け待ちへの入口から。溜まっている仕分け待ちを、新しい順に1枚ずつ出す（残りの枚数と後ろのカードも出す）
/// - `recordID` あり：撮った直後（カメラのカバーの中の `CameraFlowView`）から。今撮った1枚だけを出し、残りの枚数と後ろのカードは出さない
/// - `importedIDs` あり：アルバムからの取り込みのあと（ホーム）。取り込んだ写真だけを新しい順に出し、上の行の下に取り込んだ枚数を 1 行で出す
///
/// 閉じるのは `dismiss()`。✕ で抜けたときと、最後の1枚を仕分けたとき。抜けた分は仕分け待ちに残る。
/// この画面は上の行（✕・残り枚数）と空のときを持つ。カード・ラベル・ドラッグは `SortCardStackView`。
/// 提案されたタグの行（`SortSuggestedTagsView`）はこの画面が作り、`SortCardStackView` の下のラベルの下に置いてもらう。
/// 外したタグは記録ごとに画面の中だけで持ち、ジャンルを付けて次に進むときに `SortTagSelection.commit` で記録に書く。
///
/// 上の行の右端の「おまかせ」（機能26）は、提案のジャンルに自信がある写真（`AutoSortPolicy`）だけを、1 枚ずつ先頭に出して
/// `SortCardStackView` に飛ばしてもらう。保存は手で仕分けたときと同じ `onSort` の経路。撮った直後の 1 枚だけのときは出さない。
struct SortView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @Environment(\.suggestionService) private var suggestionService
    /// 出す写真。`init` で条件を決める（`recordID` があれば、その1件が仕分け待ちのあいだだけ入る）
    @Query private var records: [Record]
    /// 撮った直後の仕分けで、出す1枚の id。`nil` なら溜まっている仕分け待ちを出す
    private let singleRecordID: UUID?
    /// アルバムから取り込んだ写真の id。`nil` なら絞らない。
    /// `#Predicate` の中で配列の `contains` を使うと実行時に失敗する例があるので、`@Query` では絞らず `visibleRecords` で絞る
    private let importedIDs: Set<UUID>?
    /// 取り込んだ枚数・除外した枚数。上の行の下に出す
    private let importSummary: PhotoImportResult?

    /// カードが飛んでいる間。✕ を受け付けない（`SortCardStackView` と共有する）
    @State private var isCommitting = false
    /// 開いた時点で仕分け待ちが0件だったか。最初の描画では nil（まだ控えていない）
    @State private var wasEmptyAtOpen: Bool?
    /// 記録の `id` ごとの、外したタグ。付いているタグではなく外したほうを持つので、提案が後から届いても全部付いた状態で出る。
    /// 記録には書かない（書くのは次に進むとき）。仕分けを抜けたら捨てる
    @State private var removedTags: [UUID: Set<Tag>] = [:]
    /// おまかせの間。ボタンが「止める」になり、手で触れる操作を受け付けない
    @State private var isAutoSorting = false
    /// おまかせで次に飛ばす写真。先頭に出す（自信の無い写真は後ろに回る）
    @State private var autoTargetID: UUID?
    /// おまかせで `SortCardStackView` に飛ばしてもらう 1 枚
    @State private var autoFlightRequest: AutoFlightRequest?
    /// 上の行の下に 2 秒だけ出す知らせ
    @State private var notice: Notice?
    /// おまかせの途中に ✕ を押したとき。飛んでいる 1 枚が飛び切って保存されてから閉じる
    @State private var dismissesAfterFlight = false
    /// 上の行（と取り込みの件数の行）の高さ。知らせをその下に重ねるのに使う
    @State private var headerHeight: CGFloat = 0

    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。`SortCardStackView` にそのまま渡す
    private let previewDragOffset: CGSize
    /// プレビュー「1 つ外した」で使う、外したタグの初期値。まだ付け外ししていない記録に当てる
    private let previewRemovedTags: Set<Tag>
    /// プレビュー「おまかせ中」で使う。開いたときにおまかせを始める
    private let previewStartsAutoSorting: Bool
    /// プレビューで知らせの見た目を見るための文。知らせが無いときに出す
    private let previewNotice: String?

    /// 上の行の下に 2 秒だけ出す知らせ。同じ文を続けて出しても、あとのほうで消えるように id を持つ
    private struct Notice: Equatable {
        let id = UUID()
        let text: String
    }

    /// `recordID` は、撮った直後の仕分けで今撮った1枚だけを出すときに渡す。
    /// 引数の `dragOffset` は `previewDragOffset` に入れる。プレビューでドラッグの途中を見るためだけに渡す。
    /// `removedTags`・`startsAutoSorting`・`notice` も同じく、プレビューで見た目を見るためだけに渡す。
    init(
        recordID: UUID? = nil, dragOffset: CGSize = .zero, removedTags: Set<Tag> = [], startsAutoSorting: Bool = false,
        notice: String? = nil
    ) {
        self.init(
            recordID: recordID, importedIDs: nil, importSummary: nil, dragOffset: dragOffset, removedTags: removedTags,
            startsAutoSorting: startsAutoSorting, notice: notice)
    }

    /// アルバムから取り込んだ写真だけを出すとき。`importSummary` は上の行の下に 1 行で出す。
    init(importedIDs: [UUID], importSummary: PhotoImportResult) {
        self.init(
            recordID: nil, importedIDs: Set(importedIDs), importSummary: importSummary, dragOffset: .zero,
            removedTags: [], startsAutoSorting: false, notice: nil)
    }

    private init(
        recordID: UUID?, importedIDs: Set<UUID>?, importSummary: PhotoImportResult?, dragOffset: CGSize,
        removedTags: Set<Tag>, startsAutoSorting: Bool, notice: String?
    ) {
        previewStartsAutoSorting = startsAutoSorting
        previewNotice = notice
        singleRecordID = recordID
        self.importedIDs = importedIDs
        self.importSummary = importSummary
        previewDragOffset = dragOffset
        previewRemovedTags = removedTags
        let unsorted = Self.unsorted
        if let recordID {
            _records = Query(
                filter: #Predicate<Record> { $0.genre == unsorted && $0.id == recordID },
                sort: \Record.takenAt, order: .reverse
            )
        } else {
            _records = Query(
                filter: #Predicate<Record> { $0.genre == unsorted },
                sort: \Record.takenAt, order: .reverse
            )
        }
    }

    /// 画面に出す写真。取り込みから開いたときは、取り込んだ写真だけ。それ以外は `records` のまま
    private var visibleRecords: [Record] {
        guard let importedIDs else { return records }
        return records.filter { importedIDs.contains($0.id) }
    }

    /// カードに出す並び。おまかせで次に飛ばす写真を先頭に出す。それ以外は `visibleRecords` のまま
    private var displayedRecords: [Record] {
        AutoSortPolicy.movingToFront(visibleRecords, id: autoTargetID)
    }

    /// おまかせのボタンを出すか。撮った直後の 1 枚だけのときは出さない（手でスワイプするほうが速い）
    private var showsAutoSortButton: Bool {
        singleRecordID == nil
    }

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                header
                if let importSummary {
                    importSummaryLine(importSummary)
                }
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { headerHeight = $0 }
            if !displayedRecords.isEmpty {
                SortCardStackView(
                    records: displayedRecords,
                    isCommitting: $isCommitting,
                    previewDragOffset: previewDragOffset,
                    autoFlightRequest: autoFlightRequest,
                    isAutoSorting: isAutoSorting,
                    onSort: { record, genre in
                        SortTagSelection.commit(record, genre: genre, removed: removed(for: record), store: store)
                        removedTags[record.id] = nil
                        // おまかせを止めたあとに飛び切った 1 枚なら、先頭に出す指定をここで外す（保存が済んでから）
                        if record.id == autoTargetID, !isAutoSorting {
                            clearAutoTarget()
                        }
                    },
                    onToggleFavorite: { record in store.toggleFavorite(record) }
                ) {
                    // 先頭の写真の提案されたタグ。カードの外（下のラベルの下）に置く（スワイプと取り違えないように）
                    if let record = displayedRecords.first {
                        SortSuggestedTagsView(
                            tags: record.suggestedTagValues,
                            removed: removed(for: record),
                            isEnabled: !isCommitting && !isAutoSorting,
                            // 先頭の写真だけ読む（待っている写真が変わるたびの描き直しを小さくする）
                            isWaiting: record.suggestedAt == nil && suggestionService.isPending(record.id)
                        ) { tag in
                            toggle(tag, for: record)
                        }
                    }
                }
            } else if wasEmptyAtOpen ?? true {
                emptyView
            } else {
                // 仕分けて空になったときは、カバーが閉じる間に「仕分け待ちはありません」を見せない
                Color.clear
            }
        }
        // 知らせは上の行の下に重ねて出す（出る・消えるでカードの大きさが変わらないように）
        .overlay(alignment: .top) {
            if let text = notice?.text ?? previewNotice {
                noticeView(text)
                    .padding(.top, headerHeight)
            }
        }
        // カードを幅いっぱいに広げる。下はセーフエリアの内側まで使う
        .padding(.horizontal, 16)
        .background(Theme.background)
        .onAppear {
            wasEmptyAtOpen = visibleRecords.isEmpty
            // まだ問い合わせていない写真の提案を、裏で問い合わせる（通信できなかった分の問い合わせ直しも兼ねる）。
            // 並び順（新しい順）で頼むので、先に出る写真から埋まる。撮った直後の1枚は、カメラ側と重なっても Service が弾く
            for record in visibleRecords where record.suggestedAt == nil {
                suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
            }
        }
        .onChange(of: visibleRecords.isEmpty) { _, isEmpty in
            // 最後の1枚を仕分けたらホームへ
            if isEmpty {
                dismiss()
            }
        }
        .onChange(of: isCommitting) { _, isCommitting in
            // おまかせの途中に ✕ を押したときは、飛んでいた 1 枚が保存されてから閉じる
            if !isCommitting && dismissesAfterFlight {
                dismiss()
            }
        }
        // 止める（ボタン・✕）・画面を抜けると、`isAutoSorting` が変わるか画面が消えて、このタスクが取り消される
        .task(id: isAutoSorting) {
            guard isAutoSorting else { return }
            await runAutoSort()
        }
        .task {
            if previewStartsAutoSorting {
                isAutoSorting = true
            }
        }
    }

    // MARK: おまかせ

    /// 任せられる写真を 1 枚ずつ、先頭に出してから飛ばしてもらう。任せられる写真が無くなるか、止められたら終わる。
    /// 飛ばす間隔は、先頭に出す → 飛ぶ前に 0.25 秒止める（`SortCardStackView`）→ 飛ぶ → 次まで 0.2 秒
    private func runAutoSort() async {
        var flownCount = 0
        while isAutoSorting, !Task.isCancelled {
            // 手で飛ばしていた 1 枚が残っていれば、飛び終わるのを待つ
            guard await waitUntil(timeout: Self.autoFlightTimeout, { !isCommitting }) else { break }
            guard let next = AutoSortPolicy.nextTarget(in: visibleRecords),
                let genre = next.suggestedGenreValue,
                let direction = SwipeDirection(suggestedGenre: genre)
            else { break }
            // 先頭の入れ替えは、アニメーション無しで行う（後ろのカードの位置から手前に動いて見えないように）
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoTargetID = next.id
            }
            // 入れ替えた並びが `SortCardStackView` に届いてから頼む（先頭が違うと飛ばない）
            try? await Task.sleep(for: .milliseconds(50))
            guard isAutoSorting, !Task.isCancelled else { break }
            autoFlightRequest = AutoFlightRequest(token: UUID(), recordID: next.id, direction: direction)
            // 飛び始めたら数える（ここで止められても、飛び始めた 1 枚は飛び切って保存される）
            guard await waitUntil(timeout: .milliseconds(500), { isCommitting }) else { break }
            flownCount += 1
            guard await waitUntil(timeout: Self.autoFlightTimeout, { !isCommitting }) else { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        finishAutoSort(flownCount: flownCount)
    }

    /// 1 枚が飛び終わるまで待つ上限。これを過ぎたら止める（二重に飛ばさない・止まらないのを防ぐ）
    private static let autoFlightTimeout: Duration = .seconds(2)

    /// 条件が満たされるまで 0.05 秒ごとに見る。満たされたら true。時間切れ・取り消されたら false
    private func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard !Task.isCancelled, ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    /// 止めたとき・終わったとき。飛んでいる途中（止めの 0.25 秒を含む）なら、先頭に出す指定は残す。
    /// ここで外すと並びが戻って先頭が変わり、飛んでいる写真が山に戻ってしまう。外すのは、その 1 枚が保存されたとき（`onSort`）
    private func finishAutoSort(flownCount: Int) {
        // まだ飛び始めていない頼みは取り消す（遅れて届いても飛ばさない。飛んでいる 1 枚は飛び切らせる）
        autoFlightRequest = nil
        if !isCommitting {
            clearAutoTarget()
        }
        isAutoSorting = false
        if flownCount > 0 {
            show("\(flownCount) 枚おまかせしました")
        }
    }

    /// 先頭の入れ替えを、アニメーション無しで元の並びに戻す
    private func clearAutoTarget() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            autoTargetID = nil
        }
    }

    /// 「おまかせ」「止める」を押したとき。任せられる写真が無ければ、始めずに知らせる
    private func toggleAutoSort() {
        if isAutoSorting {
            isAutoSorting = false
        } else if AutoSortPolicy.eligibleCount(in: visibleRecords) == 0 {
            show("自信のある写真がまだありません")
        } else {
            isAutoSorting = true
        }
    }

    private func show(_ text: String) {
        let newNotice = Notice(text: text)
        notice = newNotice
        // 2 秒で消えるので、読み上げには出たときに知らせる
        AccessibilityNotification.Announcement(text).post()
        Task {
            try? await Task.sleep(for: .seconds(2))
            if notice == newNotice {
                notice = nil
            }
        }
    }

    private func removed(for record: Record) -> Set<Tag> {
        removedTags[record.id] ?? previewRemovedTags
    }

    /// チップを押したとき。外す／付けるを切り替える。写真は次に進まない
    private func toggle(_ tag: Tag, for record: Record) {
        // 飛んでいる間・おまかせの間は受け付けない（読み上げからのダブルタップも。ジャンルのラベルの `commit` と揃える）
        guard !isCommitting, !isAutoSorting else { return }
        removedTags = SortTagSelection.toggled(tag, for: record.id, in: removedTags, initial: previewRemovedTags)
    }

    /// 左に ✕、真ん中に「あと n 枚」、右に「おまかせ」。左右の枠を同じ幅にして、真ん中の文字が画面の中央からずれず、
    /// 文字が大きくても右のボタンと重ならないようにする
    private var header: some View {
        HStack(spacing: 8) {
            // 位置は仮（画面設計で抜ける手段の形はまだ決まっていない）
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.font(.title2))
                    .padding(8)
            }
            // おまかせの間は、飛んでいても押せる（止めて、飛び切ってから閉じる）
            .disabled(isCommitting && !isAutoSorting)
            .accessibilityLabel("仕分けを抜けてホームへ")
            .frame(maxWidth: .infinity, alignment: .leading)
            // 撮った直後は今撮った1枚だけなので、残りの枚数は出さない
            if singleRecordID == nil {
                // 数字だけ大きくする（色は黒のまま）。数字は `verbatim` にして「1,000」のような桁区切りを入れない
                Text(
                    "あと \(Text(verbatim: "\(displayedRecords.count)").font(Theme.font(.title, bold: true)).foregroundStyle(Theme.textPrimary)) 枚"
                )
                .font(Theme.font(.headline, bold: true))
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
                // 読み上げは、今までどおり「あと N 枚」
                .accessibilityLabel(Text(verbatim: "あと \(displayedRecords.count) 枚"))
            }
            Group {
                if showsAutoSortButton {
                    autoSortButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// ✕。おまかせで飛んでいる途中なら、止めて、飛び切ってから閉じる
    private func close() {
        if isAutoSorting {
            isAutoSorting = false
        }
        if isCommitting {
            dismissesAfterFlight = true
        } else {
            dismiss()
        }
    }

    /// 上の行の右端の「おまかせ」。任せられる枚数を添える。0 枚のときは薄く（押すと知らせる）。おまかせの間は「止める」
    private var autoSortButton: some View {
        let count = AutoSortPolicy.eligibleCount(in: visibleRecords)
        let isDimmed = !isAutoSorting && count == 0
        return Button {
            toggleAutoSort()
        } label: {
            // 入り切らないとき（狭い画面・文字が大きいとき）は、文字を省いてアイコンと枚数だけにする
            ViewThatFits(in: .horizontal) {
                autoSortLabel(count: count, showsTitle: true)
                autoSortLabel(count: count, showsTitle: false)
            }
            .font(Theme.font(.subheadline, bold: true))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(Theme.line, lineWidth: Theme.lineWidthBubble)
            }
            .opacity(isDimmed ? 0.4 : 1)
            // 真ん中の「あと n 枚」と重ならないよう、文字の大きさは Large で止める（ジャンルのラベルと同じ）
            .dynamicTypeSize(...DynamicTypeSize.large)
            .frame(minHeight: Theme.minTapHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAutoSorting ? "おまかせを止める" : "おまかせで仕分ける。任せられる写真 \(count) 枚")
    }

    private func autoSortLabel(count: Int, showsTitle: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isAutoSorting ? "stop.fill" : "wand.and.stars")
            if showsTitle {
                Text(isAutoSorting ? "止める" : "おまかせ")
            }
            if !isAutoSorting {
                Text(verbatim: "\(count)")
                    .font(Theme.font(.caption, bold: true))
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// 上の行の下に 2 秒だけ出す知らせ
    private func noticeView(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Theme.font(.subheadline, bold: true))
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.surface, in: .capsule)
            .overlay {
                Capsule().stroke(Theme.line, lineWidth: Theme.lineWidthThin)
            }
            .padding(.top, 4)
    }

    /// 「取り込み n 枚 ／ 除外 m 枚」。読めなかった写真があるときだけ「／ 読めなかった k 枚」を足す
    private func importSummaryLine(_ summary: PhotoImportResult) -> some View {
        Text(verbatim: summary.summaryText)
            .font(Theme.font(.subheadline, bold: true))
            .foregroundStyle(Theme.textSecondaryStrong)
            // 文字が大きくて折り返したときも真ん中にそろえる
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(verbatim: summary.summaryAccessibilityLabel))
    }

    /// 開いた時点で仕分け待ちが0件のときの保険。
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("仕分け待ちはありません")
            Button("ホームへ") {
                dismiss()
            }
            .accessibilityLabel("ホームへ戻る")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("1枚") {
    SortView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("複数枚") {
    SortView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("うまいが付いている") {
    SortView()
        .modelContainer(SortPreviewData.makeFavoriteContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("横長の写真") {
    SortView()
        .modelContainer(SortPreviewData.makeLandscapeContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("カメラから（今撮った1枚だけ）") {
    // 仕分け待ちが3件ある中で、そのうち1件だけを出す
    let container = SortPreviewData.makeManyUnsortedContainer()
    SortView(recordID: SortPreviewData.newestUnsortedID(in: container))
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("取り込みから（2 枚・除外 1 枚）") {
    // 仕分け待ちが3件ある中で、新しい2件を取り込んだ写真に見立てる
    let container = SortPreviewData.makeManyUnsortedContainer()
    let ids = Array(SortPreviewData.unsortedIDs(in: container).prefix(2))
    SortView(importedIDs: ids, importSummary: PhotoImportResult(importedIDs: ids, excludedCount: 1))
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("取り込みから・読めなかったあり") {
    let container = SortPreviewData.makeManyUnsortedContainer()
    let ids = Array(SortPreviewData.unsortedIDs(in: container).prefix(2))
    SortView(importedIDs: ids, importSummary: PhotoImportResult(importedIDs: ids, excludedCount: 3, failedCount: 2))
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xxxLarge)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("おまかせ・任せられる 2 枚") {
    SortView()
        .modelContainer(SortPreviewData.makeAutoSortContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("おまかせ・0 枚") {
    SortView(notice: "自信のある写真がまだありません")
        .modelContainer(SortPreviewData.makeAutoSortContainer(sureCount: 0))
        .environment(\.photoStorage, SampleData.photoStorage)
}

/// 静止画では、最初の 1 枚（自信のある食べ物）が先頭に出てスタンプが出た瞬間になる。キャンバスで動かすと 2 枚飛んで 2 枚残る
#Preview("おまかせ中") {
    SortView(startsAutoSorting: true)
        .modelContainer(SortPreviewData.makeAutoSortContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("おまかせ・終わった知らせ") {
    SortView(notice: "2 枚おまかせしました")
        .modelContainer(SortPreviewData.makeAutoSortContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

/// 狭い画面・文字を大きくしたときに、上の行の ✕・あと n 枚・おまかせが重ならないかを見る
#Preview("おまかせ・幅 375pt・文字サイズ XXX Large") {
    SortView()
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xxxLarge)
        .modelContainer(SortPreviewData.makeAutoSortContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("ドラッグ途中") {
    SortView(dragOffset: CGSize(width: 85, height: -10))
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

/// 画面の幅が一番狭い機種（iPhone SE 第3世代・13 mini 相当の幅 375pt）で、上のラベルと「う、うまい」が重ならないかを見る。
/// 文字サイズは X Large（ラベルは上限の Large で止まる。「う、うまい」は絵なので文字サイズで変わらない）
#Preview("幅 375pt・文字サイズ X Large") {
    SortView()
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xLarge)
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("提案あり（ラーメン）") {
    SortView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen.immediate)
}

#Preview("提案あり・1つ外した") {
    SortView(removedTags: [.chinese])
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen.immediate)
}

#Preview("提案なし") {
    SortView()
        .modelContainer(SortPreviewData.makeUnsuggestedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.noSuggestion.immediate)
}

#Preview("通信できない") {
    SortView()
        .modelContainer(SortPreviewData.makeUnsuggestedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.disabled)
}

/// 提案が届くのを待っている間。タグの行に「提案を待っています…」が薄く出る
#Preview("提案を待っている") {
    SortView()
        .modelContainer(SortPreviewData.makeUnsuggestedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.waiting)
}

/// 静止画では「届く前」になる。キャンバスで動かして、0.3 秒後に届いたときにカードが跳ねないかを見る
#Preview("後から届く") {
    SortView()
        .modelContainer(SortPreviewData.makeUnsuggestedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen)
}

#Preview("ドラッグ途中・提案あり") {
    SortView(dragOffset: CGSize(width: 10, height: -85))
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen.immediate)
}

/// 狭い画面・文字サイズ最大で、ラベル・タグの行・上の行・「う、うまい」が重ならないかを見る
#Preview("幅 375pt・文字サイズ最大・提案あり") {
    SortView()
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.accessibility5)
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen.immediate)
}
