import SwiftData
import SwiftUI
import UIKit

/// 記録1件の写真を `PhotoStorage` から読んで出す。写真本体かサムネイルかは `kind` で選ぶ。
/// `SortCardView` と同じ型（地の上に重ねてから切り抜く・記録が変わったときだけ読む）。一覧（#12）のグリッドでも使える。
/// 大きさと枠（`photoFrame`）は呼ぶ側が決める。押せる場所の `accessibilityLabel` も呼ぶ側の `Button` に付ける。
struct RecordPhotoView: View {
    enum Kind {
        /// 写真本体。ホームの今日の一枚など、大きく出す場所で使う
        case photo
        /// サムネイル。小さく並べる場所で使う（フルサイズを並べるとメモリ不足で落ちる）
        case thumbnail
    }

    let record: Record
    let kind: Kind
    /// お気に入りの記録に「うまい」を重ねるか。出すだけで、押して付け外しはできない（付けるのは仕分けの「う、うまい」と記録の詳細の「うまい」）
    var showsFavoriteLabel = false

    @Environment(\.photoStorage) private var photoStorage
    @State private var image: UIImage?

    var body: some View {
        // `scaledToFill` の写真がはみ出して大きさを決めないよう、地の上に重ねてから切り抜く
        Theme.surface
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        // 切り抜いても、はみ出した部分の当たり判定は残り、隣のタップを奪うので外す
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .overlay(alignment: .topTrailing) {
                if showsFavoriteLabel && record.isFavorite {
                    favoriteLabel
                }
            }
            // `@Query` の更新のたびに読み直さないよう、ファイルは記録が変わったときだけ読む
            .task(id: record.id) {
                switch kind {
                case .photo:
                    image = photoStorage.photo(fileName: record.photoFileName)
                case .thumbnail:
                    image = photoStorage.thumbnail(id: record.id)
                }
            }
    }

    /// 写真本体（今日の一枚など）での「うまい」の絵の幅（pt）
    private static let favoriteBadgeWidthLarge: CGFloat = 80
    /// サムネイルでの「うまい」の絵の幅（pt）
    private static let favoriteBadgeWidthSmall: CGFloat = 48

    /// 「うまい」の絵（かえでさん作。色付き）を写真の右上に傾けて置く。
    /// 絵なので文字サイズでは大きさを変えない。写真本体では大きく、サムネイルでは小さく出す
    private var favoriteLabel: some View {
        let isLarge = kind == .photo
        return Image(.umaiBadge)
            .resizable()
            .scaledToFit()
            .frame(width: isLarge ? Self.favoriteBadgeWidthLarge : Self.favoriteBadgeWidthSmall)
            .rotationEffect(Theme.favoriteTilt)
            // 傾けると角が数 pt はみ出すので、写真の縁から少し離す
            .padding(isLarge ? 12 : 6)
            // 読み上げは呼ぶ側の `Button` のラベルに含める
            .accessibilityHidden(true)
    }
}

#Preview {
    let container = SampleData.makePreviewContainer()
    // お気に入りの記録で「うまい」を見る。プレビュー用なので、無ければ落として気づく
    let descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.isFavorite })
    let record = try! container.mainContext.fetch(descriptor).first!
    HStack(spacing: 16) {
        RecordPhotoView(record: record, kind: .photo, showsFavoriteLabel: true)
            .frame(width: 160, height: 160)
        RecordPhotoView(record: record, kind: .thumbnail, showsFavoriteLabel: true)
            .frame(width: 80, height: 80)
        RecordPhotoView(record: record, kind: .thumbnail)
            .frame(width: 80, height: 80)
    }
    .modelContainer(container)
    .environment(\.photoStorage, SampleData.photoStorage)
}
