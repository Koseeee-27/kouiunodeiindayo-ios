import SwiftData
import SwiftUI
import UIKit

/// 記録1件の写真を `PhotoStorage` から読んで出す。写真本体かサムネイルかは `kind` で選ぶ。
/// `SortCardView` と同じ型（地の上に重ねてから切り抜く・記録が変わったときだけ読む）。一覧（#12）のグリッドでも使える。
/// 大きさと角丸は呼ぶ側が決める。押せる場所の `accessibilityLabel` も呼ぶ側の `Button` に付ける。
struct RecordPhotoView: View {
    enum Kind {
        /// 写真本体。ホームの今日の一枚など、大きく出す場所で使う
        case photo
        /// サムネイル。小さく並べる場所で使う（フルサイズを並べるとメモリ不足で落ちる）
        case thumbnail
    }

    let record: Record
    let kind: Kind

    @Environment(\.photoStorage) private var photoStorage
    @State private var image: UIImage?

    var body: some View {
        // `scaledToFill` の写真がはみ出して大きさを決めないよう、地の上に重ねてから切り抜く
        Color.secondary.opacity(0.2)
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
}

#Preview {
    let container = SampleData.makePreviewContainer()
    // プレビュー用なので、無ければ落として気づく
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first!
    HStack(spacing: 16) {
        RecordPhotoView(record: record, kind: .photo)
            .frame(width: 160, height: 160)
        RecordPhotoView(record: record, kind: .thumbnail)
            .frame(width: 80, height: 80)
    }
    .modelContainer(container)
    .environment(\.photoStorage, SampleData.photoStorage)
}
