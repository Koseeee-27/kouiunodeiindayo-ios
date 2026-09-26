import SwiftData
import SwiftUI

/// 仕分け。写真のカードを4方向にスワイプ（またはラベルを押す）してジャンルを付け、「う、うまい」でお気に入りを付け外しする。
/// 要素と操作は `docs/screen-design.md` の「仕分け」、スワイプを自作する理由は `docs/adr/0005-swipe-ui.md` が正。
/// 開き方は2つ。下タブには載らない。
/// - `recordID` なし：ホーム・一覧の仕分け待ちへの入口から。溜まっている仕分け待ちを、新しい順に1枚ずつ出す（残りの枚数と後ろのカードも出す）
/// - `recordID` あり：撮った直後（カメラのカバーの中の `CameraFlowView`）から。今撮った1枚だけを出し、残りの枚数と後ろのカードは出さない
///
/// 閉じるのは `dismiss()`。✕ で抜けたときと、最後の1枚を仕分けたとき。抜けた分は仕分け待ちに残る。
/// この画面は上の行（✕・残り枚数）と空のときを持つ。カード・ラベル・ドラッグは `SortCardStackView`。
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

    /// カードが飛んでいる間。✕ を受け付けない（`SortCardStackView` と共有する）
    @State private var isCommitting = false
    /// 開いた時点で仕分け待ちが0件だったか。最初の描画では nil（まだ控えていない）
    @State private var wasEmptyAtOpen: Bool?

    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。`SortCardStackView` にそのまま渡す
    private let previewDragOffset: CGSize

    /// `recordID` は、撮った直後の仕分けで今撮った1枚だけを出すときに渡す。
    /// 引数の `dragOffset` は `previewDragOffset` に入れる。プレビューでドラッグの途中を見るためだけに渡す。
    init(recordID: UUID? = nil, dragOffset: CGSize = .zero) {
        singleRecordID = recordID
        previewDragOffset = dragOffset
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

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if !records.isEmpty {
                SortCardStackView(
                    records: records,
                    isCommitting: $isCommitting,
                    previewDragOffset: previewDragOffset,
                    onSort: { record, genre in store.setGenre(genre, for: record) },
                    onToggleFavorite: { record in store.toggleFavorite(record) }
                )
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
            wasEmptyAtOpen = records.isEmpty
            // まだ問い合わせていない写真の提案を、裏で問い合わせる（通信できなかった分の問い合わせ直しも兼ねる）。
            // 並び順（新しい順）で頼むので、先に出る写真から埋まる。撮った直後の1枚は、カメラ側と重なっても Service が弾く
            for record in records where record.suggestedAt == nil {
                suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
            }
        }
        .onChange(of: records.isEmpty) { _, isEmpty in
            // 最後の1枚を仕分けたらホームへ
            if isEmpty {
                dismiss()
            }
        }
    }

    private var header: some View {
        ZStack {
            // 撮った直後は今撮った1枚だけなので、残りの枚数は出さない
            if singleRecordID == nil {
                // 数字だけ大きくする（色は黒のまま）。数字は `verbatim` にして「1,000」のような桁区切りを入れない
                Text(
                    "あと \(Text(verbatim: "\(records.count)").font(Theme.font(.title, bold: true)).foregroundStyle(Theme.textPrimary)) 枚"
                )
                .font(Theme.font(.headline, bold: true))
                // 読み上げは、今までどおり「あと N 枚」
                .accessibilityLabel(Text(verbatim: "あと \(records.count) 枚"))
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
