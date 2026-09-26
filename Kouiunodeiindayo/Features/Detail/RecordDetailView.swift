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

/// 記録1件ぶんの詳細。写真（本体）・日付・ジャンルを出し、「うまい」の付け外し、記録を消す（右上の「…」から）、閉じるができる。
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
        VStack(spacing: 16) {
            HStack {
                closeButton
                Spacer()
                moreMenu
            }
            photo
            Text(verbatim: dateText)
                .font(Theme.font(.headline, bold: true))
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
            favoriteButton
            genreButtons
            Spacer(minLength: 0)
        }
        .padding()
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
    }

    /// 「2026年9月10日」の形。数字を直接埋め込むと「2,026」と桁区切りが入るので、`verbatim` で渡す
    private var dateText: String {
        let date = Calendar.current.dateComponents([.year, .month, .day], from: record.takenAt)
        return "\(date.year ?? 0)年\(date.month ?? 0)月\(date.day ?? 0)日"
    }

    /// 付け直せるジャンル。「なし」は選択肢に置かず、選択中のジャンルをもう一度押して外す
    private static let selectableGenres: [Genre] = [.food, .drink, .dessert]

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .photoFrame(.main)
        } else {
            Theme.surface
                .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
                .photoFrame(.main)
        }
    }

    /// 「うまい」。写真には重ねず、ジャンルの上に置く。押すたびに付け外しする
    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(record)
        } label: {
            Text("うまい")
                .font(Theme.font(.headline, bold: true))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .rect)
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
                        .font(Theme.font(.subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(isSelected ? Theme.onMain : Theme.textPrimary)
                        .background(
                            isSelected ? AnyShapeStyle(Theme.main) : AnyShapeStyle(.regularMaterial),
                            in: .rect(cornerRadius: 8))
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
