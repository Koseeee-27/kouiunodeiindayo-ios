import SwiftUI

/// 仕分けのカードの重なりと、4方向のラベル。ドラッグ・ラベルを押したときにカードを飛ばし、飛び終わってからジャンルを付ける。
/// 仕分け待ちの読み込み（`@Query`）と、上の行（✕・残り枚数）は `SortView` が持つ。
struct SortCardStackView: View {
    /// 仕分け待ち（`SortView` の `@Query` の結果）。先頭2件だけ使う
    let records: [Record]
    /// カードが飛んでいる間。ジェスチャー・ラベル・✕・「う、うまい」を受け付けない。✕ を持つ `SortView` と共有する
    @Binding var isCommitting: Bool
    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。
    /// `@GestureState` は外から値を入れられないので、指で動かしていないときだけこちらを使う
    let previewDragOffset: CGSize
    /// 仕分けが決まったとき（飛び終わったとき）。ジャンルを付ける
    let onSort: (Record, Genre) -> Void
    let onToggleFavorite: (Record) -> Void

    /// 指で動かしている間の移動量。離したときも、iOS がジェスチャーを取り消したとき（通知センターを引き出すなど）も、
    /// `onEnded` を待たずにバネで 0 に戻る
    @GestureState(resetTransaction: Transaction(animation: .spring)) private var dragTranslation: CGSize = .zero
    /// 仕分けて画面の外へ飛ばしている間のカードの位置
    @State private var flyOffset: CGSize = .zero
    /// いま飛ばしている記録の id。300ms の保険が、あとから飛ばした別の記録を戻さないように控える
    @State private var flyingRecordID: UUID?

    /// カードの表示位置。傾きとラベルの強調もここから決める
    private var cardOffset: CGSize {
        if isCommitting {
            return flyOffset
        }
        return dragTranslation == .zero ? previewDragOffset : dragTranslation
    }

    var body: some View {
        GeometryReader { geometry in
            sortArea(screenSize: geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: records.first?.id) {
            if isCommitting {
                resetAfterCommit()
            }
        }
    }

    /// ラベルはカードと一緒に動かさず、手前のカードの縁（上・下・左・右の真ん中）に固定する。
    /// `overlay` はカードの `ZStack` より手前に描かれるので、飛んでいくカードにもラベルが隠れない
    private func sortArea(screenSize: CGSize) -> some View {
        let highlighted = SwipeDirection.direction(for: cardOffset)
        return cardStack(screenSize: screenSize)
            .overlay(alignment: .top) {
                genreLabel(.up, highlighted: highlighted, screenSize: screenSize)
                    .padding(.top, Self.labelInset)
            }
            .overlay(alignment: .leading) {
                genreLabel(.left, highlighted: highlighted, screenSize: screenSize)
                    .padding(.leading, Self.labelInset)
            }
            .overlay(alignment: .trailing) {
                genreLabel(.right, highlighted: highlighted, screenSize: screenSize)
                    .padding(.trailing, Self.labelInset)
            }
            .overlay(alignment: .bottom) {
                genreLabel(.down, highlighted: highlighted, screenSize: screenSize)
                    .padding(.bottom, Self.labelInset)
            }
            // 手前のカードの下を空け、後ろのカードの下端が見える隙間にする。ラベルは手前のカードの縁に合わせるので、この外側で空ける
            .padding(.bottom, SwipeDirection.backCardPeek)
    }

    /// ラベルをカードの縁からどれだけ内側に置くか（pt）。縁をまたぐと、左右 16pt の余白しかないので画面の外にはみ出す
    private static let labelInset: CGFloat = 12

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
                    onToggleFavorite: { onToggleFavorite(record) }
                )
                // 後ろのカードは下端をそろえて小さくし、手前のカードの下の隙間から下端をのぞかせる
                .scaleEffect(isFront ? 1.0 : SwipeDirection.backCardScale, anchor: .bottom)
                .offset(y: isFront ? 0 : SwipeDirection.backCardPeek)
                // 回転 → 移動の順（ADR 0005）。逆にすると回転した座標系で動く
                .rotationEffect(isFront ? SwipeDirection.rotation(for: cardOffset) : .zero)
                .offset(isFront ? cardOffset : .zero)
                .gesture(dragGesture(screenSize: screenSize), isEnabled: isFront && !isCommitting)
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            onSort(record, direction.genre)
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
}
