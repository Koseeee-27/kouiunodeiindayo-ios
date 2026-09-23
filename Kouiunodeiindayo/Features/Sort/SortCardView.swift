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
        // `scaledToFill` の写真がはみ出して大きさを決めないよう、地の上に重ねてから切り抜く
        Color.secondary.opacity(0.2)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        // 切り抜いても、はみ出した部分の当たり判定は残り、横のラベルのタップを奪うので外す
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
        .disabled(!isFavoriteEnabled)
        .opacity(record.isFavorite ? 1.0 : 0.4)
        .padding(12)
        .accessibilityLabel("う、うまい")
        .accessibilityAddTraits(record.isFavorite ? .isSelected : [])
    }
}
