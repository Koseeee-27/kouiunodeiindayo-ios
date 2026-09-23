import SwiftUI
import UIKit

/// 仕分けの写真 1 枚のカード。右上の「う、うまい」でお気に入りを付け外しする（写真は次に進まない）。
/// ドラッグと仕分けは `SortView` が持つ。
struct SortCardView: View {
    let record: Record
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
        Button(action: onToggleFavorite) {
            Text("う、うまい")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .opacity(record.isFavorite ? 1.0 : 0.4)
        .padding(12)
        .accessibilityLabel("う、うまい")
        .accessibilityAddTraits(record.isFavorite ? .isSelected : [])
    }
}
