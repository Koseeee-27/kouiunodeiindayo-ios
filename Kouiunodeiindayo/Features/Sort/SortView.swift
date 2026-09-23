import SwiftData
import SwiftUI

/// 仕分け。写真のカードを4方向にスワイプ（またはラベルを押す）してジャンルを付け、「う、うまい」でお気に入りを付け外しする。
/// 要素と操作は `docs/screen-design.md` の「仕分け」、スワイプを自作する理由は `docs/adr/0005-swipe-ui.md` が正。
/// 今は撮ったあと（カメラのカバーの中の `CameraFlowView`）から開く。下タブには載らない。
/// 閉じるのは `dismiss()`。✕ で抜けたときと、最後の1枚を仕分けたとき。抜けた分は仕分け待ちに残る。
/// 出す順番は仕分け待ちの新しい順（`@Query` の並びそのまま）。撮った直後の1枚が一番新しいので、先頭に来る。
struct SortView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @Query(
        filter: #Predicate<Record> { $0.genre == unsorted },
        sort: \Record.takenAt, order: .reverse
    )
    private var records: [Record]

    @State private var dragOffset: CGSize
    /// カードが飛んでいる間。ジェスチャー・ラベル・✕・「う、うまい」を受け付けない
    @State private var isCommitting = false

    /// `dragOffset` はプレビューでドラッグの途中を見るためだけに渡す。
    init(dragOffset: CGSize = .zero) {
        _dragOffset = State(initialValue: dragOffset)
    }

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                header
                if !records.isEmpty {
                    sortArea(screenSize: geometry.size)
                } else {
                    emptyView
                }
            }
            .padding()
        }
        .onChange(of: records.first?.id) {
            if isCommitting {
                resetAfterCommit()
            }
        }
        .onChange(of: records.isEmpty) { _, isEmpty in
            // 最後の1枚を仕分けたらホームへ
            if isEmpty {
                dismiss()
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("あと \(records.count) 枚")
                .font(.headline)
            HStack {
                // 位置は仮（画面設計で抜ける手段の形はまだ決まっていない）
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding(8)
                }
                .disabled(isCommitting)
                .accessibilityLabel("仕分けを抜けてホームへ")
                Spacer()
            }
        }
    }

    private func sortArea(screenSize: CGSize) -> some View {
        let highlighted = SwipeDirection.direction(for: dragOffset)
        return VStack(spacing: 12) {
            genreLabel(.up, highlighted: highlighted, screenSize: screenSize)
            HStack(spacing: 8) {
                genreLabel(.left, highlighted: highlighted, screenSize: screenSize)
                cardStack(screenSize: screenSize)
                    // 飛んでいくカードがラベルの下に潜らないよう、手前に描く
                    .zIndex(1)
                genreLabel(.right, highlighted: highlighted, screenSize: screenSize)
            }
            .zIndex(1)
            genreLabel(.down, highlighted: highlighted, screenSize: screenSize)
        }
        // ラベルをカードに寄せたまま、残りの高さの真ん中に置く
        .frame(maxHeight: .infinity)
    }

    /// 手前と後ろの2枚を、記録の id で並べる。後ろのカードが手前に来ても同じビューのままなので、
    /// 写真を読み直さず、読み込み中の灰色の地も出ない。
    private func cardStack(screenSize: CGSize) -> some View {
        ZStack {
            // 後ろのカードを先に描き、手前のカードをその上に重ねる
            ForEach(Array(records.prefix(2).reversed()), id: \.id) { record in
                let isFront = record.id == records.first?.id
                SortCardView(
                    record: record,
                    isFavoriteEnabled: isFront && !isCommitting,
                    onToggleFavorite: { store.toggleFavorite(record) }
                )
                .scaleEffect(isFront ? 1.0 : 0.95)
                .offset(y: isFront ? 0 : 12)
                // 回転 → 移動の順（ADR 0005）。逆にすると回転した座標系で動く
                .rotationEffect(isFront ? SwipeDirection.rotation(for: dragOffset) : .zero)
                .offset(isFront ? dragOffset : .zero)
                .gesture(dragGesture(screenSize: screenSize), isEnabled: isFront && !isCommitting)
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }

    private func dragGesture(screenSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if let direction = SwipeDirection.committed(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                ) {
                    commit(direction, screenSize: screenSize)
                } else {
                    withAnimation(.spring) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func genreLabel(_ direction: SwipeDirection, highlighted: SwipeDirection?, screenSize: CGSize)
        -> some View
    {
        SortGenreLabel(
            genre: direction.genre,
            isVertical: direction == .left || direction == .right,
            emphasis: highlighted.map { $0 == direction ? .strong : .weak } ?? .normal
        ) {
            commit(direction, screenSize: screenSize)
        }
        .disabled(isCommitting)
    }

    /// 手前のカードを `direction` の向きに飛ばし、飛び終わってからジャンルを付ける。
    /// 先に付けると `@Query` からその記録がすぐ消え、飛んでいる途中のカードが消えてしまうため。
    private func commit(_ direction: SwipeDirection, screenSize: CGSize) {
        guard !isCommitting, let record = records.first else { return }
        isCommitting = true
        withAnimation(.easeIn(duration: 0.25)) {
            dragOffset = direction.offscreenOffset(in: screenSize)
        } completion: {
            // 位置は、`@Query` から記録が消えて先頭が変わったときに戻す（`resetAfterCommit`）。
            // ここで一緒に戻すと、`@Query` の更新が遅れたとき、仕分けた写真が真ん中に一瞬戻って見える
            store.setGenre(direction.genre, for: record)
        }
    }

    /// 次のカードが元の位置からすぐ出るよう、アニメーション無しで戻す。
    private func resetAfterCommit() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = .zero
            isCommitting = false
        }
    }

    /// 開いた時点で仕分け待ちが0件のときの保険。
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("仕分け待ちはありません")
            Button("ホームへ") {
                dismiss()
            }
            .accessibilityLabel("ホームへ戻る")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// 仕分けのラベル。押すと、その向きにスワイプしたのと同じになる。
private struct SortGenreLabel: View {
    enum Emphasis {
        case normal
        /// ドラッグ中、この向きに向いている
        case strong
        /// ドラッグ中、ほかの向きに向いている
        case weak
    }

    let genre: Genre
    /// 左右のラベルは、カードの幅を取らないようアイコンと文字を縦に積む（文字は横書き）
    let isVertical: Bool
    let emphasis: Emphasis
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if isVertical {
                    VStack(spacing: 4) {
                        Image(systemName: genre.systemImage)
                        Text(genre.title)
                    }
                } else {
                    Label(genre.title, systemImage: genre.systemImage)
                }
            }
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(emphasis == .strong ? 1.2 : 1.0)
        .opacity(emphasis == .weak ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.15), value: emphasis)
        .accessibilityLabel("\(genre.title)にする")
    }
}

#Preview("1枚") {
    SortView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("複数枚") {
    SortView()
        .modelContainer(makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("うまいが付いている") {
    SortView()
        .modelContainer(makeFavoriteContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("ドラッグ途中") {
    SortView(dragOffset: CGSize(width: 60, height: -10))
        .modelContainer(makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

/// サンプルデータに仕分け待ちを2件足したもの（仕分け待ちは計3件）。
@MainActor
private func makeManyUnsortedContainer() -> ModelContainer {
    let container = SampleData.makePreviewContainer()
    let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
    for (index, color) in [UIColor.systemGreen, .systemPurple].enumerated() {
        let takenAt = Date.now.addingTimeInterval(-60 * 60 * Double(index + 1))
        // プレビュー用なので、作れなければ落として気づく
        _ = try! store.add(image: SampleData.makeImage(color: color), takenAt: takenAt)
    }
    return container
}

/// サンプルデータの仕分け待ちに「うまい」を付けたもの。
@MainActor
private func makeFavoriteContainer() -> ModelContainer {
    let container = SampleData.makePreviewContainer()
    let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
    let unsorted = Genre.unsorted.rawValue
    let descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.genre == unsorted })
    // プレビュー用なので、無ければ落として気づく
    let record = try! container.mainContext.fetch(descriptor).first!
    store.toggleFavorite(record)
    return container
}
