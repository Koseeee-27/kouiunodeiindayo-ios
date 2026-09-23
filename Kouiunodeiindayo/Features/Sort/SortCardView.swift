import SwiftData
import SwiftUI
import UIKit

/// 仕分けの写真 1 枚のカード。右上の「う、うまい」でお気に入りを付け外しする（写真は次に進まない）。
/// ドラッグと仕分けは `SortView` が持つ。
struct SortCardView: View {
    let record: Record
    /// カードが飛んでいる間は false にして、「う、うまい」を押せなくする
    let isFavoriteEnabled: Bool
    let onToggleFavorite: () -> Void

    @Environment(\.photoStorage) private var photoStorage
    @State private var photo: UIImage?

    var body: some View {
        // 写真の縦横比は崩さない。全体が見えるよう `scaledToFit` で真ん中に置き、
        // 余った部分には同じ写真を `scaledToFill` でぼかして敷く。
        // 写真がはみ出して大きさを決めないよう、地の上に重ねてから切り抜く。ぼかしと写真は別々の `overlay` にする
        // （同じ `ZStack` に入れると、はみ出した地の大きさが手前の写真にも渡り、手前の写真まで切り抜かれてしまう）
        Color.secondary.opacity(0.2)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        // 縁が透けて灰色の地が見えないよう、ぼかしの縁も不透明にする
                        .blur(radius: 30, opaque: true)
                        // 切り抜いても、はみ出した部分の当たり判定は残り、ラベルのタップを奪うので外す
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                        .accessibilityLabel("仕分ける写真")
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                favoriteButton
            }
            // ドラッグ中は毎フレーム `body` が呼ばれるので、ファイルは記録が変わったときだけ読む
            .task(id: record.id) {
                photo = photoStorage.photo(fileName: record.photoFileName)
            }
    }

    private var favoriteButton: some View {
        Button {
            onToggleFavorite()
        } label: {
            Text("う、うまい")
                .font(.headline)
                // 大きな文字サイズで「…」に省略されないよう、縮めて1行に収める
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        // 上のラベルと同じ縁に並ぶので、ラベルと同じ上限を付ける（幅 375pt の機種では X Large でくっつく）
        .dynamicTypeSize(...DynamicTypeSize.large)
        // `.disabled` だと薄い色になり、うまいが付いていないように見えるので、押せなくするだけにする
        .allowsHitTesting(isFavoriteEnabled)
        .opacity(record.isFavorite ? 1.0 : 0.4)
        .padding(12)
        .accessibilityLabel("う、うまい")
        .accessibilityAddTraits(record.isFavorite ? .isSelected : [])
    }
}

#Preview("横長の写真") {
    let container = SortPreviewData.makeLandscapeContainer()
    let unsorted = Genre.unsorted.rawValue
    let descriptor = FetchDescriptor<Record>(
        predicate: #Predicate { $0.genre == unsorted },
        sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
    )
    // プレビュー用なので、無ければ落として気づく
    let record = try! container.mainContext.fetch(descriptor).first!
    SortCardView(record: record, isFavoriteEnabled: true, onToggleFavorite: {})
        .frame(width: 360, height: 640)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}
