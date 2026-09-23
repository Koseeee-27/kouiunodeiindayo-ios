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

    /// 指で動かしている間の移動量。離したときも、iOS がジェスチャーを取り消したとき（通知センターを引き出すなど）も、
    /// `onEnded` を待たずにバネで 0 に戻る
    @GestureState(resetTransaction: Transaction(animation: .spring)) private var dragTranslation: CGSize = .zero
    /// 仕分けて画面の外へ飛ばしている間のカードの位置
    @State private var flyOffset: CGSize = .zero
    /// カードが飛んでいる間。ジェスチャー・ラベル・✕・「う、うまい」を受け付けない
    @State private var isCommitting = false
    /// いま飛ばしている記録の id。300ms の保険が、あとから飛ばした別の記録を戻さないように控える
    @State private var flyingRecordID: UUID?
    /// 開いた時点で仕分け待ちが0件だったか。最初の描画では nil（まだ控えていない）
    @State private var wasEmptyAtOpen: Bool?

    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。
    /// `@GestureState` は外から値を入れられないので、指で動かしていないときだけこちらを使う
    private let previewDragOffset: CGSize

    /// 引数の `dragOffset` は `previewDragOffset` に入れる。プレビューでドラッグの途中を見るためだけに渡す。
    init(dragOffset: CGSize = .zero) {
        previewDragOffset = dragOffset
    }

    /// カードの表示位置。傾きとラベルの強調もここから決める
    private var cardOffset: CGSize {
        if isCommitting {
            return flyOffset
        }
        return dragTranslation == .zero ? previewDragOffset : dragTranslation
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
                } else if wasEmptyAtOpen ?? true {
                    emptyView
                } else {
                    // 仕分けて空になったときは、カバーが閉じる間に「仕分け待ちはありません」を見せない
                    Color.clear
                }
            }
            .padding()
        }
        .onAppear {
            wasEmptyAtOpen = records.isEmpty
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
        let highlighted = SwipeDirection.direction(for: cardOffset)
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
                .rotationEffect(isFront ? SwipeDirection.rotation(for: cardOffset) : .zero)
                .offset(isFront ? cardOffset : .zero)
                .gesture(dragGesture(screenSize: screenSize), isEnabled: isFront && !isCommitting)
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }

    private func dragGesture(screenSize: CGSize) -> some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            // しきい値に届かなかったとき・取り消されたときは、`dragTranslation` がバネで戻るので何もしない
            .onEnded { value in
                if let direction = SwipeDirection.committed(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                ) {
                    commit(direction, from: value.translation, screenSize: screenSize)
                }
            }
    }

    private func genreLabel(_ direction: SwipeDirection, highlighted: SwipeDirection?, screenSize: CGSize)
        -> some View
    {
        SortGenreLabelView(
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
    /// `start` はスワイプで離した瞬間の位置。そこから飛ばすことで、見た目が途切れない（ラベルを押したときは 0）
    private func commit(_ direction: SwipeDirection, from start: CGSize = .zero, screenSize: CGSize) {
        guard !isCommitting, let record = records.first else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flyOffset = start
            isCommitting = true
            flyingRecordID = record.id
        }
        withAnimation(.easeIn(duration: 0.25)) {
            flyOffset = direction.offscreenOffset(in: screenSize)
        } completion: {
            // 位置は、`@Query` から記録が消えて先頭が変わったときに戻す（`resetAfterCommit`）。
            // ここで一緒に戻すと、`@Query` の更新が遅れたとき、仕分けた写真が真ん中に一瞬戻って見える
            store.setGenre(direction.genre, for: record)
            // 保険：先頭が変わらず `onChange` が来ないと `isCommitting` が残り、✕ も効かず抜けられなくなる
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                if flyingRecordID == record.id {
                    resetAfterCommit()
                }
            }
        }
    }

    /// 次のカードが元の位置からすぐ出るよう、アニメーション無しで戻す。
    private func resetAfterCommit() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flyOffset = .zero
            isCommitting = false
            flyingRecordID = nil
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

#Preview("1枚") {
    SortView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("複数枚") {
    SortView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("うまいが付いている") {
    SortView()
        .modelContainer(SortPreviewData.makeFavoriteContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("ドラッグ途中") {
    SortView(dragOffset: CGSize(width: 60, height: -10))
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
