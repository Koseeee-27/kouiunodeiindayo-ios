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
    /// お気に入りの記録に「うまい」を重ねるか。出すだけで、押して付け外しはできない（付けるのは仕分けと記録の詳細の「うまい」）
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

    /// 仕分けのハンコの絵と同じ横長の長方形を、アプリ側で描いて写真の右上に傾けて置く（絵は線が細く、サムネイルでは潰れるため）。
    /// 写真本体（今日の一枚など）では大きく、サムネイルでは小さく出す
    private var favoriteLabel: some View {
        let isLarge = kind == .photo
        return Text("うまい")
            .font(isLarge ? Theme.font(.headline, bold: true) : Theme.font(.caption, bold: true))
            .foregroundStyle(Theme.accent)
            // 文字サイズ最大でサムネイルに入り切らず「…」にならないよう、縮めて1行に収める（サムネイルは幅が 80pt ほどしかない）
            .lineLimit(1)
            .minimumScaleFactor(isLarge ? 0.5 : 0.3)
            // 横長に見えるよう、左右の余白を上下より大きく取る
            .padding(.horizontal, isLarge ? 14 : 7)
            .padding(.vertical, isLarge ? 6 : 3)
            .background(Theme.background, in: .rect)
            .overlay {
                Rectangle()
                    .strokeBorder(Theme.accent, lineWidth: isLarge ? Theme.lineWidthThick : Theme.lineWidthThin)
            }
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
