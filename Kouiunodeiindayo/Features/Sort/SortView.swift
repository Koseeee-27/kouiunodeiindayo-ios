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

    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。`SortCardStackView` にそのまま渡す
    private let previewDragOffset: CGSize
    /// プレビュー「1 つ外した」で使う、外したタグの初期値。まだ付け外ししていない記録に当てる
    private let previewRemovedTags: Set<Tag>

    /// `recordID` は、撮った直後の仕分けで今撮った1枚だけを出すときに渡す。
    /// 引数の `dragOffset` は `previewDragOffset` に入れる。プレビューでドラッグの途中を見るためだけに渡す。
    /// `removedTags` も同じく、プレビューで外したタグの見た目を見るためだけに渡す。
    init(recordID: UUID? = nil, dragOffset: CGSize = .zero, removedTags: Set<Tag> = []) {
        self.init(
            recordID: recordID, importedIDs: nil, importSummary: nil, dragOffset: dragOffset, removedTags: removedTags)
    }

    /// アルバムから取り込んだ写真だけを出すとき。`importSummary` は上の行の下に 1 行で出す。
    init(importedIDs: [UUID], importSummary: PhotoImportResult) {
        self.init(
            recordID: nil, importedIDs: Set(importedIDs), importSummary: importSummary, dragOffset: .zero,
            removedTags: [])
    }

    private init(
        recordID: UUID?, importedIDs: Set<UUID>?, importSummary: PhotoImportResult?, dragOffset: CGSize,
        removedTags: Set<Tag>
    ) {
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
            if !visibleRecords.isEmpty {
                SortCardStackView(
                    records: visibleRecords,
                    isCommitting: $isCommitting,
                    previewDragOffset: previewDragOffset,
                    onSort: { record, genre in
                        SortTagSelection.commit(record, genre: genre, removed: removed(for: record), store: store)
                        removedTags[record.id] = nil
                    },
                    onToggleFavorite: { record in store.toggleFavorite(record) }
                ) {
                    // 先頭の写真の提案されたタグ。カードの外（下のラベルの下）に置く（スワイプと取り違えないように）
                    if let record = visibleRecords.first {
                        SortSuggestedTagsView(
                            tags: record.suggestedTagValues,
                            removed: removed(for: record),
                            isEnabled: !isCommitting
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
    }

    private func removed(for record: Record) -> Set<Tag> {
        removedTags[record.id] ?? previewRemovedTags
    }

    /// チップを押したとき。外す／付けるを切り替える。写真は次に進まない
    private func toggle(_ tag: Tag, for record: Record) {
        // 飛んでいる間は受け付けない（読み上げからのダブルタップも。ジャンルのラベルの `commit` と揃える）
        guard !isCommitting else { return }
        removedTags = SortTagSelection.toggled(tag, for: record.id, in: removedTags, initial: previewRemovedTags)
    }

    private var header: some View {
        ZStack {
            // 撮った直後は今撮った1枚だけなので、残りの枚数は出さない
            if singleRecordID == nil {
                // 数字だけ大きくする（色は黒のまま）。数字は `verbatim` にして「1,000」のような桁区切りを入れない
                Text(
                    "あと \(Text(verbatim: "\(visibleRecords.count)").font(Theme.font(.title, bold: true)).foregroundStyle(Theme.textPrimary)) 枚"
                )
                .font(Theme.font(.headline, bold: true))
                // 読み上げは、今までどおり「あと N 枚」
                .accessibilityLabel(Text(verbatim: "あと \(visibleRecords.count) 枚"))
            }
            HStack {
                // 位置は仮（画面設計で抜ける手段の形はまだ決まっていない）
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(.title2))
                        .padding(8)
                }
                .disabled(isCommitting)
                .accessibilityLabel("仕分けを抜けてホームへ")
                Spacer()
            }
        }
    }

    /// 「取り込み n 枚 ／ 除外 m 枚」。読めなかった写真があるときだけ「／ 読めなかった k 枚」を足す
    private func importSummaryLine(_ summary: PhotoImportResult) -> some View {
        Text(verbatim: summary.summaryText)
            .font(Theme.font(.caption))
            .foregroundStyle(Theme.textSecondary)
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
