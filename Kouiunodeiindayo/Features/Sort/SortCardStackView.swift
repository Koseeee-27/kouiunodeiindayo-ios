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
    /// いま飛ばしている向き。飛んでいる間のスタンプに使う
    @State private var flyingDirection: SwipeDirection?
    /// 仕分けが決まった回数。決まった瞬間の振動のきっかけにする
    @State private var commitCount = 0
    /// 仕分けが決まって、後ろのカードを手前の大きさ・位置までせり上げている間
    @State private var isNextRising = false

    /// カードの表示位置。傾きとラベルの強調もここから決める
    private var cardOffset: CGSize {
        if isCommitting {
            return flyOffset
        }
        return dragTranslation == .zero ? previewDragOffset : dragTranslation
    }

    /// 指で動かしていて、離せば仕分けになる向き。超えた瞬間（戻して超え直したときも）に軽く振動させる
    private var pendingCommit: SwipeDirection? {
        isCommitting ? nil : SwipeDirection.pendingCommit(for: cardOffset)
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
        // 振動は実機でしか確かめられない。強さとタイミングは実機で調整する
        .sensoryFeedback(trigger: pendingCommit) { _, new in
            new != nil ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: commitCount)
    }

    /// ラベルはカードと一緒に動かさず、手前のカードの縁（上・下・左・右の真ん中）に固定する。
    /// `overlay` はカードの `ZStack` より手前に描かれるので、飛んでいくカードにもラベルが隠れない
    private func sortArea(screenSize: CGSize) -> some View {
        // 飛んでいる間は、飛ばしている向き（仕分けたジャンル）を強調する。飛ぶ位置から決めると、斜めに飛んだときに別の向きになる
        let highlighted = isCommitting ? flyingDirection : SwipeDirection.direction(for: cardOffset)
        return cardStack(screenSize: screenSize)
            .overlay(alignment: .top) {
                // 上のラベルは、カードの上の縁の外に出す（右上の「う、うまい」のハンコと重ならないように）
                genreLabel(.up, highlighted: highlighted, screenSize: screenSize)
                    .padding(.bottom, Self.outerLabelGap)
                    .alignmentGuide(.top) { $0[.bottom] }
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
                // 下のラベルも、カードの下の縁の外に出す
                genreLabel(.down, highlighted: highlighted, screenSize: screenSize)
                    .padding(.top, Self.outerLabelGap)
                    .alignmentGuide(.bottom) { $0[.top] }
            }
            // 手前のカードの下を空け、後ろのカードの下端が見える隙間にする。ラベルは手前のカードの縁に合わせるので、この外側で空ける
            .padding(.bottom, SwipeDirection.backCardPeek)
    }

    /// 上と下のラベルを、カードの縁からどれだけ外に離すか（pt）
    private static let outerLabelGap: CGFloat = 8
    /// ラベルをカードの縁からどれだけ内側に置くか（pt）。縁をまたぐと、左右 16pt の余白しかないので画面の外にはみ出す
    private static let labelInset: CGFloat = 12
    /// スタンプをカードの上端からどれだけ下に置くか（pt）。上のラベルと「う、うまい」に重ならない高さ
    private static let stampTopInset: CGFloat = 130

    /// 手前と後ろの2枚を、記録の id で並べる。後ろのカードが手前に来ても同じビューのままなので、
    /// 写真を読み直さず、読み込み中の灰色の地も出ない。
    private func cardStack(screenSize: CGSize) -> some View {
        let progress = SwipeDirection.progress(for: cardOffset)
        // 飛んでいる間は、飛ばしている向きのスタンプを濃さ 1 で出す（ラベルを押したときも）
        let stampDirection = isCommitting ? flyingDirection : SwipeDirection.direction(for: cardOffset)
        let stampOpacity = isCommitting ? 1 : progress
        // 後ろのカードは、ドラッグで進むほど手前の大きさに近づき、仕分けが決まったらバネで手前の大きさになる。
        // 手前に来た時点ですでに手前と同じ大きさ・位置なので、切り替わっても跳ねない
        let backScale = isNextRising ? 1 : SwipeDirection.backCardScale + (1 - SwipeDirection.backCardScale) * progress
        let backPeek = isNextRising ? 0 : SwipeDirection.backCardPeek * (1 - progress)
        return ZStack {
            // 後ろのカードを先に描き、手前のカードをその上に重ねる
            ForEach(Array(records.prefix(2).reversed()), id: \.id) { record in
                let isFront = record.id == records.first?.id
                // 位置・傾き・スタンプを付けるカード。飛んでいる間は、先頭ではなく飛ばしている記録に付ける。
                // `@Query` の更新から `onChange` で戻すまでの間に、新しい先頭が飛ぶ位置（画面の外）に出ないように
                let isMoving = isCommitting ? record.id == flyingRecordID : isFront
                SortCardView(
                    record: record,
                    isFavoriteEnabled: isFront && !isCommitting,
                    onToggleFavorite: { onToggleFavorite(record) }
                )
                // スタンプはカードと一緒に動く。真ん中だと、左右に動かしたときに左右のラベル（縦の真ん中）の下に潜るので、
                // 上のラベルの下あたりに置く
                .overlay(alignment: .top) {
                    if isMoving, let stampDirection {
                        SortStampView(genre: stampDirection.genre)
                            .opacity(stampOpacity)
                            .padding(.top, Self.stampTopInset)
                    }
                }
                // 後ろのカードは下端をそろえて小さくし、手前のカードの下の隙間から下端をのぞかせる
                .scaleEffect(isFront ? 1.0 : backScale, anchor: .bottom)
                .offset(y: isFront ? 0 : backPeek)
                // 回転 → 移動の順（ADR 0005）。逆にすると回転した座標系で動く
                .rotationEffect(isMoving ? SwipeDirection.rotation(for: cardOffset) : .zero)
                .offset(isMoving ? cardOffset : .zero)
                .gesture(dragGesture(screenSize: screenSize), isEnabled: isFront && !isCommitting)
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        // カードは 3:4。ラベルの `overlay` はこの後に付くので、ラベルもカードの縁に付く（先に付けると、場所全体の縁に残ってカードから浮く）。
        // 場所の真ん中に置くのは、`body` の `frame` が受け持つ
        .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
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
                    let flight = SwipeDirection.flight(
                        from: value.translation,
                        velocity: value.velocity,
                        direction: direction,
                        in: screenSize
                    )
                    commit(direction, from: value.translation, flight: flight, screenSize: screenSize)
                }
            }
    }

    private func genreLabel(_ direction: SwipeDirection, highlighted: SwipeDirection?, screenSize: CGSize)
        -> some View
    {
        SortGenreLabelView(
            direction: direction,
            genre: direction.genre,
            emphasis: highlighted.map { $0 == direction ? .strong : .weak } ?? .normal
        ) {
            commit(direction, screenSize: screenSize)
        }
        // `.disabled` だと飛んでいる間にラベルが薄くなり、向かっている向きの強調も消えるので、押せなくするだけにする。
        // 読み上げから押された場合も、`commit` の先頭で止まる
        .allowsHitTesting(!isCommitting)
    }

    /// 手前のカードを `direction` の向きに飛ばし、飛び終わってからジャンルを付ける。
    /// 先に付けると `@Query` からその記録がすぐ消え、飛んでいる途中のカードが消えてしまうため。
    /// `start` はスワイプで離した瞬間の位置。そこから飛ばすことで、見た目が途切れない（ラベルを押したときは 0）。
    /// `flight` はスワイプで払った勢いの飛び先と時間。ラベルを押したときは nil で、仕分けの向きにまっすぐ飛ばす
    private func commit(
        _ direction: SwipeDirection,
        from start: CGSize = .zero,
        flight: (offset: CGSize, duration: TimeInterval)? = nil,
        screenSize: CGSize
    ) {
        guard !isCommitting, let record = records.first else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flyOffset = start
            isCommitting = true
            flyingRecordID = record.id
            flyingDirection = direction
        }
        commitCount += 1
        // バネはせり上がりだけに付ける。位置（`flyOffset`）の戻しに効くと、次のカードが画面の外から飛んでくるように見える
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            isNextRising = true
        }
        let animation: Animation = flight.map { .linear(duration: $0.duration) } ?? .easeIn(duration: 0.25)
        withAnimation(animation) {
            flyOffset = flight?.offset ?? direction.offscreenOffset(in: screenSize)
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
            flyingDirection = nil
            isNextRising = false
        }
    }
}
