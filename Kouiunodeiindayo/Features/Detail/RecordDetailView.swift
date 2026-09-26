import OSLog
import SwiftData
import SwiftUI
import UIKit

/// 記録の詳細。写真（本体）・日付・ジャンルを出し、「うまい」の付け外し、記録を消す（右上の「…」から）、閉じるができる。
/// 要素と操作は `docs/screen-design.md` の「記録の詳細」が正。
/// ホーム・一覧から sheet で開く。sheet なので、閉じても元の画面のスクロール位置はそのまま残る。
struct RecordDetailView: View {
    private static let logger = Logger(category: "RecordDetailView")

    let record: Record

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
            favoriteButton
            genreButtons
            Spacer(minLength: 0)
        }
        .padding()
        .background(Theme.background)
        // 記録が変わったときだけファイルを読む（写真本体）
        .task(id: record.id) {
            image = photoStorage.photo(fileName: record.photoFileName)
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
    let container = SampleData.makePreviewContainer()
    // ジャンルが付いている記録で、ジャンルの表示も見る。プレビュー用なので、無ければ落として気づく
    let food = Genre.food.rawValue
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>(predicate: #Predicate { $0.genre == food }))
        .first!
    RecordDetailView(record: record)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}
