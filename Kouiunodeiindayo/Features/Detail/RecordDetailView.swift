import OSLog
import SwiftData
import SwiftUI
import UIKit

/// 記録の詳細。開いた元の並び（ホーム・一覧の新しい順）のまま、左右にスワイプして前後の記録に移れる。端ではそれ以上動かない。
/// 1件ぶんの画面は `RecordDetailPageView`。ホーム・一覧から sheet で開く。sheet なので、閉じても元の画面のスクロール位置はそのまま残る。
struct RecordDetailView: View {
    let records: [Record]
    /// 今出ている記録の `id`。`init` で開いた記録に決める（宣言時に初期値を持つ `@State` に `init` で代入しないため）
    @State private var selectedID: UUID

    /// `records` は開いた元の並び。`initial` がその中に無いときは、`initial` だけを出す
    init(records: [Record], initial: Record) {
        self.records = records.contains { $0.id == initial.id } ? records : [initial]
        _selectedID = State(initialValue: initial.id)
    }

    var body: some View {
        // ページごとに探し直さないよう、今の位置は1回だけ求める
        let currentIndex = selectedIndex
        // 指についてくる横スワイプにするため、記録を `.page` スタイルのページャーに横に並べる
        TabView(selection: $selectedID) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                RecordDetailPageView(
                    record: record, position: index + 1, total: records.count,
                    // 今のページと、その前後1件だけ写真を読む（全件の写真本体を一度に持つと、メモリ不足で落ちる）
                    shouldLoadPhoto: abs(index - currentIndex) <= 1
                ) { delta in
                    move(from: index, by: delta)
                }
                .tag(record.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // ページャーはセーフエリアまで地を広げないので、ここでも地を敷く
        .background(Theme.background)
    }

    /// 今出ている記録の位置。見つからないときは先頭
    private var selectedIndex: Int {
        records.firstIndex { $0.id == selectedID } ?? 0
    }

    /// VoiceOver から前後の記録へ移る。端では動かない
    private func move(from index: Int, by delta: Int) {
        let next = index + delta
        guard records.indices.contains(next) else { return }
        withAnimation {
            selectedID = records[next].id
        }
    }
}

/// 記録1件ぶんの詳細。写真（本体）・日付・ジャンル・タグを出し、「うまい」の付け外し、タグの付け外し（一番下の行と、
/// 「＋ タグ」から開くタグの一覧）、記録を消す（右上の「…」から）、閉じるができる。
/// 要素と操作は `docs/screen-design.md` の「記録の詳細」が正。
struct RecordDetailPageView: View {
    private static let logger = Logger(category: "RecordDetailView")

    let record: Record
    /// 開いた元の並びの中での位置（1始まり）と件数。VoiceOver の読み上げに使う
    let position: Int
    let total: Int
    /// 写真本体を読むか。今のページの近くだけ true にして、遠いページは写真を持たない
    let shouldLoadPhoto: Bool
    /// VoiceOver から前後の記録へ移る（-1 が前、1 が次）
    let onMove: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @State private var image: UIImage?
    @State private var isDeleteConfirmationShown = false
    @State private var isDeleteFailureShown = false
    /// 消したあと、閉じ終わるまでの間に、消えた記録を読まないための印
    @State private var isDeleted = false
    /// タグの一覧（シート）を開いているか
    @State private var isTagPickerShown = false

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        // ふだんはスクロールせずに 1 画面に収める（写真が残りの高さに合わせて縮む）。
        // タグが多い・文字サイズが大きいなどで、写真を `photoMinHeight` より小さくしないと入らないときだけ、縦にスクロールする版にする。
        // 縦のスクロールは、左右のめくり（ページャー）とは取り合わない
        ViewThatFits(in: .vertical) {
            layout(fillsHeight: true)
            ScrollView {
                layout(fillsHeight: false)
            }
        }
        .background(Theme.background)
        // 記録が変わったときだけファイルを読む（写真本体）
        .task(id: shouldLoadPhoto ? record.id : nil) {
            image = shouldLoadPhoto ? photoStorage.photo(fileName: record.photoFileName) : nil
        }
        // iOS 26 の `confirmationDialog` は「やめる」を出さない（外をタップして閉じる）ので、「消す」と「やめる」が並ぶ `alert` にする
        .alert("この記録を消しますか？", isPresented: $isDeleteConfirmationShown) {
            Button("消す", role: .destructive) {
                delete()
            }
            Button("やめる", role: .cancel) {}
        }
        .alert("消せませんでした", isPresented: $isDeleteFailureShown) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $isTagPickerShown) {
            TagPickerView(record: record)
        }
    }

    /// 上に ✕ と「…」。その下に、写真・日付・「うまい」・ジャンル・タグを決まった間隔でまとめて置く。
    /// 1 画面に収める版では、余った高さをまとまりの上と下に同じだけ空けて、画面の縦の真ん中に置く（要素の間は広げない）
    private func layout(fillsHeight: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                closeButton
                Spacer()
                moreMenu
            }
            Spacer(minLength: Self.blockGap)
            VStack(spacing: Self.blockSpacing) {
                // 写真と日付は、近づけて1組にする
                VStack(spacing: Theme.detailPhotoDateSpacing) {
                    photoArea
                        // 1 画面に収まるかを測るときは、最小の高さで測る（`ViewThatFits` は理想の大きさで比べる）
                        // スクロールする版では、写真の場所を同じ高さで止め、ジャンルとタグがなるべく 1 画面に見えるようにする
                        .frame(
                            minHeight: fillsHeight ? Self.photoMinHeight : nil,
                            idealHeight: fillsHeight ? Self.photoMinHeight : nil,
                            maxHeight: fillsHeight ? nil : Self.photoMinHeight
                        )
                        // 写真の場所は、余白より先に高さを受け取る
                        .layoutPriority(1)
                    dateLabel
                }
                favoriteButton
                genreButtons
                // 付いているタグ。「何か（ジャンル）→ どんな（タグ）」の順に読めるよう、ジャンルの下に置く
                RecordDetailTagsView(
                    tags: record.tagValues,
                    onRemove: { tag in store.setTags(TagEditing.removing(tag, from: record.tagValues), for: record) },
                    onAdd: { isTagPickerShown = true }
                )
            }
            Spacer(minLength: Self.blockGap)
        }
        .padding()
    }

    /// 日付。文字が大きいときは折り返す（切れないように）
    private var dateLabel: some View {
        Text(verbatim: dateText)
            .font(Theme.font(.headline, bold: true))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // VoiceOver では「2026年9月10日、3件目、全28件」と読まれ、上下にスワイプすると前後の記録に移れる
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dateText)
            .accessibilityValue("\(position)件目、全\(total)件")
            .accessibilityHint("上下にスワイプすると、前後の記録に移ります")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onMove(1)
                case .decrement: onMove(-1)
                @unknown default: break
                }
            }
    }

    /// まとまりの中の、要素と要素の間隔（pt）
    private static let blockSpacing: CGFloat = 16
    /// ✕ の行とまとまりの間・まとまりの下に、最低限空ける高さ（pt）
    private static let blockGap: CGFloat = 8

    /// 1 画面に収める版で、写真をこれより小さくしない（pt）。これを取れないときはスクロールする版にする
    private static let photoMinHeight: CGFloat = 240

    /// 「2026年9月10日」の形。数字を直接埋め込むと「2,026」と桁区切りが入るので、`verbatim` で渡す
    private var dateText: String {
        let date = Calendar.current.dateComponents([.year, .month, .day], from: record.takenAt)
        return "\(date.year ?? 0)年\(date.month ?? 0)月\(date.day ?? 0)日"
    }

    /// 付け直せるジャンル。「なし」は選択肢に置かず、選択中のジャンルをもう一度押して外す
    private static let selectableGenres: [Genre] = [.food, .drink, .dessert]

    /// 写真の場所。3:4 の場所を取り、写真はその下にそろえて、切らずに写真の形のまま置く（縦長・横長・正方形のどれでも）。
    /// 写真と日付がいつもくっつき、横長・正方形の空きは写真の上だけに出る。
    /// 場所の形がどの記録でも同じなので、前後にめくっても日付から下の位置が変わらない。
    /// 枠は写真に付ける。ホームの今日の一枚・仕分けのカード（`.main`）より少し細い `.small`
    private var photoArea: some View {
        Color.clear
            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
            .overlay(alignment: .bottom) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)
                        .photoFrame(.small)
                } else {
                    // 読み込む前・遠いページは、場所いっぱいの地
                    Theme.surface
                        .photoFrame(.small)
                }
            }
            // 場所は横幅いっぱいまで。高さで決まるときは、左右の真ん中に置く
            .frame(maxWidth: .infinity)
    }

    /// 「うまい」。一覧・ホームと同じ絵を、日付とジャンルのボタンの間の真ん中に置く（写真には重ねない）。押すたびに付け外しする
    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(record)
        } label: {
            // 一覧・ホームと同じ「うまい」の絵（かえでさん作）。傾けずに水平に置く。絵なので文字サイズでは大きさを変えない
            Image(.umaiBadge)
                .resizable()
                .scaledToFit()
                .frame(width: Theme.detailFavoriteBadgeWidth)
                .frame(minHeight: Theme.minTapHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // 付いていないときは薄く、付いたら濃くする
        .opacity(record.isFavorite ? 1.0 : 0.4)
        .accessibilityLabel("うまい")
        .accessibilityAddTraits(record.isFavorite ? .isSelected : [])
    }

    /// 食べ物・飲み物・デザートを横に並べ、選択中のものに色を付ける。押すとその場で付け直す
    private var genreButtons: some View {
        HStack(spacing: 8) {
            ForEach(Self.selectableGenres, id: \.self) { genre in
                let isSelected = record.genreValue == genre
                Button {
                    // 選択中をもう一度押すと外れる（「なし」になる）
                    store.setGenre(isSelected ? .noGenre : genre, for: record)
                } label: {
                    Label(genre.title, systemImage: genre.systemImage)
                        .font(Theme.font(.headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapHeight)
                        .foregroundStyle(isSelected ? Theme.onMain : Theme.textPrimary)
                        .background(
                            isSelected ? AnyShapeStyle(Theme.main) : AnyShapeStyle(.regularMaterial),
                            in: .rect(cornerRadius: Theme.cornerRadiusSmall)
                        )
                        // 墨の細い枠。選ばれているとき（墨の地）は、地と同じ色で見えない
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .strokeBorder(Theme.line, lineWidth: Theme.lineWidthThin)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(genre.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// 左上の ✕。閉じる
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(Theme.font(.title2))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閉じる")
    }

    /// 右上の「…」。中に「記録を消す」を置く（日付を直す（機能13）を作ったら、ここに足す）。押すと確認が出る
    private var moreMenu: some View {
        Menu {
            Button("記録を消す", role: .destructive) {
                isDeleteConfirmationShown = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(Theme.font(.title2))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("その他")
    }

    private func delete() {
        // 先に印を付け、消えた記録を画面が読まないようにする
        isDeleted = true
        do {
            try store.delete(record)
            dismiss()
        } catch {
            Self.logger.error("記録を消せなかった: \(error.localizedDescription, privacy: .public)")
            isDeleted = false
            isDeleteFailureShown = true
        }
    }
}

#Preview {
    let container = HomePreviewData.makeManyContainer()
    // 仕分け済みを新しい順に。一覧・ホームと同じ並びで、左右にスワイプして前後に移れる。プレビュー用なので、無ければ落として気づく
    let unsorted = Genre.unsorted.rawValue
    let records = try! container.mainContext.fetch(
        FetchDescriptor<Record>(
            predicate: #Predicate { $0.genre != unsorted },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]))
    RecordDetailView(records: records, initial: records.first!)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}

/// 記録 1 件だけの詳細のプレビュー。`tags` を付けた「食べ物」の記録を開く。`photoSize` で写真の形を変えられる
@MainActor
private func taggedDetailPreview(tags: [Tag], photoSize: CGSize? = nil) -> some View {
    let container = HomePreviewData.makeTaggedContainer(tags: tags, photoSize: photoSize)
    // プレビュー用なので、無ければ落として気づく
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first!
    return RecordDetailView(records: [record], initial: record)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("タグなし") {
    taggedDetailPreview(tags: [])
}

#Preview("タグ 3 個") {
    taggedDetailPreview(tags: [.ramen, .noodles, .chinese])
}

/// 一番小さい機種（iPhone SE 第3世代。375×667）で、タグが 2 行になっても写真が小さくなりすぎないかを見る
#Preview("SE 相当・タグ 6 個") {
    taggedDetailPreview(tags: [.ramen, .gyoza, .noodles, .fried, .chinese, .japanese])
        .frame(width: 375, height: 667)
}

#Preview("SE 相当・文字サイズ XXX Large") {
    taggedDetailPreview(tags: [.ramen, .gyoza, .noodles, .fried, .chinese, .japanese])
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.xxxLarge)
}

#Preview("SE 相当・文字サイズ最大") {
    taggedDetailPreview(tags: [.ramen, .gyoza, .noodles, .fried, .chinese, .japanese])
        .frame(width: 375, height: 667)
        .dynamicTypeSize(.accessibility5)
}

// 写真の形の見比べ（#108）。縦長 3:4・横長 4:3・正方形を、ふつうの幅・SE 相当・文字サイズ最大で並べる。タグは 3 個
private let portraitSize = CGSize(width: 1200, height: 1600)
private let landscapeSize = CGSize(width: 1600, height: 1200)
private let squareSize = CGSize(width: 1400, height: 1400)
private let aspectTags: [Tag] = [.ramen, .noodles, .chinese]

#Preview("縦長・ふつう") {
    taggedDetailPreview(tags: aspectTags, photoSize: portraitSize)
}

#Preview("横長・ふつう") {
    taggedDetailPreview(tags: aspectTags, photoSize: landscapeSize)
}

#Preview("正方形・ふつう") {
    taggedDetailPreview(tags: aspectTags, photoSize: squareSize)
}

#Preview("縦長・SE 相当") {
    taggedDetailPreview(tags: aspectTags, photoSize: portraitSize)
        .frame(width: 375, height: 667)
}

#Preview("横長・SE 相当") {
    taggedDetailPreview(tags: aspectTags, photoSize: landscapeSize)
        .frame(width: 375, height: 667)
}

#Preview("正方形・SE 相当") {
    taggedDetailPreview(tags: aspectTags, photoSize: squareSize)
        .frame(width: 375, height: 667)
}

#Preview("縦長・文字サイズ最大") {
    taggedDetailPreview(tags: aspectTags, photoSize: portraitSize)
        .dynamicTypeSize(.accessibility5)
}

#Preview("横長・文字サイズ最大") {
    taggedDetailPreview(tags: aspectTags, photoSize: landscapeSize)
        .dynamicTypeSize(.accessibility5)
}

#Preview("正方形・文字サイズ最大") {
    taggedDetailPreview(tags: aspectTags, photoSize: squareSize)
        .dynamicTypeSize(.accessibility5)
}

/// 「縦長・ふつう」（タグ 3 個＝1 行）と並べて、タグが 2 行の記録にめくったときに写真と日付から下が跳ねないかを見る
#Preview("縦長・ふつう・タグ 6 個") {
    taggedDetailPreview(tags: [.ramen, .gyoza, .noodles, .fried, .chinese, .japanese], photoSize: portraitSize)
}
