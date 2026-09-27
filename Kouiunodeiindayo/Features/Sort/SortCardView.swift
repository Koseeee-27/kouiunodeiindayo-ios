import SwiftData
import SwiftUI
import UIKit

/// 仕分けの写真 1 枚のカード。渡された 3:4 の場所（大きさは `SortCardStackView` が決める）の真ん中に、写真の形のカードを置く。
/// 縦長・横長・正方形のどれでも、写真を切らずに全体を出し、枠と右上の「う、うまい」は写真の形のカードに付ける。場所の余りは透明。
/// 右上の「う、うまい」でお気に入りを付け外しする（写真は次に進まない）。ドラッグと仕分けは `SortCardStackView` が持つ。
struct SortCardView: View {
    let record: Record
    /// カードが飛んでいる間は false にして、「う、うまい」を押せなくする
    let isFavoriteEnabled: Bool
    let onToggleFavorite: () -> Void
    /// 写真を読み込んだとき、その縦横比（幅 ÷ 高さ）を知らせる。`SortCardStackView` が縁のラベルをカードの形に合わせるのに使う
    var onPhotoAspect: (CGFloat) -> Void = { _ in }
    /// カードを収める枠の縦横比。nil なら渡された場所（3:4）いっぱいに収める。
    /// 後ろのカードは手前のカードの形を渡し、その中に収めて、手前の縁からはみ出さないようにする（`SortCardStackView`）
    var boxAspectRatio: CGFloat? = nil

    @Environment(\.photoStorage) private var photoStorage
    @State private var photo: UIImage?

    /// カードの縦横比。読み込む前は 3:4（今までのカードと同じ形）
    private var aspectRatio: CGFloat {
        photo.flatMap(Self.aspectRatio(of:)) ?? Theme.photoAspectRatio
    }

    var body: some View {
        // 場所いっぱいを取り、その真ん中に写真の形のカードを置く。余りは透明で、押しても何も起きない（ドラッグも始まらない）
        // 枠は、あり・なしで別のビューにせず、いつも同じ形のビューで比だけを変える。後ろのカードが手前に来て枠が外れるとき、
        // 別のビューだと 2 枚が薄く重なって切り替わるが、同じビューなら大きさがバネで広がる（`SortCardStackView` の `withAnimation`）。
        // 枠なしは場所と同じ 3:4 なので、今までと同じ大きさになる
        Color.clear
            .overlay {
                Color.clear
                    .aspectRatio(boxAspectRatio ?? Theme.photoAspectRatio, contentMode: .fit)
                    .overlay { card }
            }
            // ドラッグ中は毎フレーム `body` が呼ばれるので、ファイルは記録が変わったときだけ読む
            .task(id: record.id) {
                photo = photoStorage.photo(fileName: record.photoFileName)
                if let photo, let aspect = Self.aspectRatio(of: photo) {
                    onPhotoAspect(aspect)
                }
            }
    }

    /// 写真の形のカード。地は読み込む前の見た目と、ドラッグを受ける面を兼ねる（写真は押す判定から外している）
    private var card: some View {
        Theme.surface
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                        .accessibilityLabel("仕分ける写真")
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .photoFrame(.main)
            .overlay(alignment: .topTrailing) {
                favoriteButton
            }
    }

    /// 写真の縦横比（幅 ÷ 高さ）。大きさが 0 の壊れた写真では nil（3:4 のままにする）
    static func aspectRatio(of photo: UIImage) -> CGFloat? {
        guard photo.size.width > 0, photo.size.height > 0 else { return nil }
        return photo.size.width / photo.size.height
    }

    /// 「う、うまい」の絵の幅（pt）
    private static let favoriteStampWidth: CGFloat = 220
    /// 「う、うまい」の絵をカードの上端からどれだけ下に置くか（pt）。傾きで、上の縁から少しはみ出す高さ。上のラベルはカードの外にあるので、重ならない
    private static let favoriteStampTopInset: CGFloat = 24

    private var favoriteButton: some View {
        Button {
            // `allowsHitTesting` は指のタップだけを止めるので、読み上げから押されたときもここで止める
            guard isFavoriteEnabled else { return }
            onToggleFavorite()
        } label: {
            // 2 つの絵は縦横比が少し違うので、幅をそろえて `scaledToFit` にし、切り替わっても位置がずれないようにする
            Image(record.isFavorite ? .umaiStamp : .umaiStampOutline)
                .resizable()
                .scaledToFit()
                .frame(width: Self.favoriteStampWidth)
                // 付けたときのハンコを押す演出（機能24）。元の傾きより先に付けて、輪も絵と一緒に傾ける
                .stampPress(isOn: record.isFavorite)
                // 色なしの絵は中が透けるので、線の上だけでなく四角全体を押せるようにする
                .contentShape(.rect)
                .rotationEffect(Theme.sortFavoriteTilt)
                // 押す前は色なしの絵を薄くし、押した後の色付きの絵との差をはっきりさせる
                .opacity(record.isFavorite ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        // `.disabled` だと薄い色になり、うまいが付いていないように見えるので、押せなくするだけにする
        .allowsHitTesting(isFavoriteEnabled)
        .padding(.top, Self.favoriteStampTopInset)
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
        .frame(width: 360, height: 480)
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}
