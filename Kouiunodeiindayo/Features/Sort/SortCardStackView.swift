import SwiftUI

/// おまかせで、先頭の写真を飛ばしてほしいとき。`token` が変わるたびに 1 回だけ飛ばす
struct AutoFlightRequest: Equatable {
    let token: UUID
    let recordID: UUID
    let direction: SwipeDirection
}

/// 仕分けのカードの重なりと、4方向のラベル。ドラッグ・ラベルを押したときにカードを飛ばし、飛び終わってからジャンルを付ける。
/// 仕分け待ちの読み込み（`@Query`）と、上の行（✕・残り枚数）は `SortView` が持つ。
/// 下のラベルのすぐ下には、`SortView` から渡された `belowCard`（提案されたタグの行）を置く。
struct SortCardStackView<BelowCard: View>: View {
    /// 仕分け待ち（`SortView` の `@Query` の結果）。先頭2件だけ使う
    let records: [Record]
    /// カードが飛んでいる間。ジェスチャー・ラベル・✕・「う、うまい」を受け付けない。✕ を持つ `SortView` と共有する
    @Binding var isCommitting: Bool
    /// プレビュー「ドラッグ途中」で使う、指で動かしている量の代わり。
    /// `@GestureState` は外から値を入れられないので、指で動かしていないときだけこちらを使う
    let previewDragOffset: CGSize
    /// おまかせで先頭の写真を飛ばしてほしいとき（`SortView` が 1 枚ずつ入れる）。先頭が `recordID` のときだけ飛ばす
    var autoFlightRequest: AutoFlightRequest? = nil
    /// おまかせの間。ドラッグ・ラベル・「う、うまい」を受け付けない（`isCommitting` と同じ扱い）
    var isAutoSorting = false
    /// 仕分けが決まったとき（飛び終わったとき）。ジャンルを付ける
    let onSort: (Record, Genre) -> Void
    let onToggleFavorite: (Record) -> Void
    /// 下のラベルのすぐ下に置くもの（提案されたタグの行）。カードと一緒には動かさない
    @ViewBuilder let belowCard: BelowCard

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
    /// 上のラベルの高さ・下のラベルと `belowCard` を合わせた高さ（測った値）。
    /// どちらもカードの縁の外にはみ出すので、その分を枠の上下に空ける
    @State private var topOuterHeight: CGFloat = 0
    @State private var bottomOuterHeight: CGFloat = 0
    /// 飛ばす先を決めるための、仕分けの場所の大きさ（おまかせで外から飛ばすときに使う）
    @State private var areaSize: CGSize = .zero
    /// 記録ごとの写真の縦横比（幅 ÷ 高さ）。カードが写真を読み込んだときに知らせてくる。縁のラベルを手前のカードの形に付けるのに使う
    @State private var photoAspects: [UUID: CGFloat] = [:]

    /// 飛んでいる間・おまかせの間は、手で触れる操作を受け付けない
    private var isInteractionLocked: Bool {
        isCommitting || isAutoSorting
    }

    /// カードの表示位置。傾きとラベルの強調もここから決める
    private var cardOffset: CGSize {
        if isCommitting {
            return flyOffset
        }
        return dragTranslation == .zero ? previewDragOffset : dragTranslation
    }

    /// 手前のカードの縦横比。写真を読み込む前は 3:4
    private var frontAspectRatio: CGFloat {
        records.first.flatMap { photoAspects[$0.id] } ?? Theme.photoAspectRatio
    }

    /// 縁のラベルを付ける枠の縦横比。ふだんは手前のカードの形。
    /// 仕分けが決まって後ろのカードがせり上がっている間は、そのカード（飛ばしている記録の次）の形にする。
    /// `isNextRising` と同じバネの中で変わるので、ラベルもカードが広がるのと一緒に新しい縁へ動く。
    /// `@Query` が更新されて先頭が入れ替わっても同じ記録を指すので、`resetAfterCommit` で戻したときに跳ばない
    private var labelAspectRatio: CGFloat {
        guard isNextRising, let next = records.first(where: { $0.id != flyingRecordID }) else {
            return frontAspectRatio
        }
        return photoAspects[next.id] ?? Theme.photoAspectRatio
    }

    /// 指で動かしていて、離せば仕分けになる向き。超えた瞬間（戻して超え直したときも）に軽く振動させる
    private var pendingCommit: SwipeDirection? {
        isCommitting ? nil : SwipeDirection.pendingCommit(for: cardOffset)
    }

    var body: some View {
        GeometryReader { geometry in
            // 上下のラベル（と、下のタグの行）の分を空けて、カードのほうを小さくする。
            // 狭い画面で、上のラベルが上の行に、下のタグの行が画面の外にかぶらないように
            sortArea(screenSize: geometry.size)
                .padding(.top, topOuterHeight + Self.outerLabelGap)
                .padding(.bottom, bottomOuterHeight + Self.outerLabelGap)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { areaSize = $0 }
        // おまかせ：飛ぶ前に 0.25 秒止めて、スタンプとラベルの強調を見せる
        .onChange(of: autoFlightRequest) { _, request in
            guard
                AutoSortPolicy.shouldStartFlight(
                    request, isAutoSorting: isAutoSorting, isCommitting: isCommitting, frontID: records.first?.id),
                let request
            else { return }
            commit(request.direction, pause: Self.autoFlightPause, screenSize: areaSize)
        }
        // 飛ばしていた記録が並びから消えたら（保存されて `@Query` から外れたら）、飛び終わりとして戻す。
        // 先頭が変わっただけ（おまかせの並べ替えが戻ったなど）では戻さない。飛んでいる途中のカードが山に戻らないように
        .onChange(of: records.map(\.id)) { _, ids in
            if isCommitting, let flyingRecordID, !ids.contains(flyingRecordID) {
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
        cardStack(screenSize: screenSize)
            .overlay {
                // カードは 3:4 の場所の真ん中に写真の形で置かれる（`SortCardView`）ので、ラベルも同じ形・同じ位置の枠に付ける。
                // 透明なので、ドラッグはその下のカードに届く
                Color.clear
                    .aspectRatio(labelAspectRatio, contentMode: .fit)
                    .overlay { edgeLabels(screenSize: screenSize) }
            }
            // 手前のカードの下を空け、後ろのカードの下端が見える隙間にする。ラベルは手前のカードの縁に合わせるので、この外側で空ける
            .padding(.bottom, SwipeDirection.backCardPeek)
    }

    /// 縁のラベル（上下左右）と、下のラベルの下の `belowCard`。手前のカードの形の枠に重ねる
    private func edgeLabels(screenSize: CGSize) -> some View {
        // 飛んでいる間は、飛ばしている向き（仕分けたジャンル）を強調する。飛ぶ位置から決めると、斜めに飛んだときに別の向きになる
        let highlighted = isCommitting ? flyingDirection : SwipeDirection.direction(for: cardOffset)
        return Color.clear
            .overlay(alignment: .top) {
                // 上のラベルは、カードの上の縁の外に出す（右上の「う、うまい」のハンコと重ならないように）
                genreLabel(.up, highlighted: highlighted, screenSize: screenSize)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        topOuterHeight = $0
                    }
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
                // 下のラベルも、カードの下の縁の外に出す。そのすぐ下に `belowCard`（提案されたタグの行）
                VStack(spacing: Theme.sortBelowLabelSpacing) {
                    genreLabel(.down, highlighted: highlighted, screenSize: screenSize)
                    belowCard
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    bottomOuterHeight = $0
                }
                .padding(.top, Self.outerLabelGap)
                .alignmentGuide(.bottom) { $0[.top] }
            }
    }

    // 型が `BelowCard` を持つ汎用の型なので、定数は `static let` で持てない（計算で返す）
    /// 上と下のラベルを、カードの縁からどれだけ外に離すか（pt）
    private static var outerLabelGap: CGFloat { 8 }
    /// ラベルをカードの縁からどれだけ内側に置くか（pt）。縁をまたぐと、左右 16pt の余白しかないので画面の外にはみ出す
    private static var labelInset: CGFloat { 12 }
    /// スタンプをカードの上端からどれだけ下に置くか（pt）。右上の「う、うまい」と重ならない高さ
    private static var stampTopInset: CGFloat { 130 }
    /// おまかせで、飛ぶ前にスタンプを見せて止める時間
    private static var autoFlightPause: Duration { .milliseconds(250) }

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
                    isFavoriteEnabled: isFront && !isInteractionLocked,
                    onToggleFavorite: {
                        // 飛んでいる間・おまかせの間は、読み上げから押されても切り替えない
                        guard !isInteractionLocked else { return }
                        onToggleFavorite(record)
                    },
                    onPhotoAspect: { photoAspects[record.id] = $0 },
                    // 後ろのカードは、手前のカードの形の中に収める（手前が横長で後ろが縦長のとき、上下からはみ出してラベルにかぶらないように）。
                    // 仕分けが決まったら、せり上がりのバネと一緒に自分の形の大きさまで広がるので、手前に来たときに跳ねない
                    boxAspectRatio: isFront || isNextRising ? nil : frontAspectRatio
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
                .gesture(dragGesture(screenSize: screenSize), isEnabled: isFront && !isInteractionLocked)
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        // カードを置く場所は 3:4。カードはその真ん中に写真の形で置かれ、ラベルは `sortArea` で同じ形の枠に付ける。
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
            emphasis: highlighted.map { $0 == direction ? .strong : .weak } ?? .normal,
            // 飛んでいる間も、先頭は飛ばしている写真のまま（`onSort` のあとで変わる）
            isSuggested: records.first?.suggestedGenreValue == direction.genre
        ) {
            // おまかせの間は、読み上げから押されても仕分けない
            guard !isAutoSorting else { return }
            commit(direction, screenSize: screenSize)
        }
        // `.disabled` だと飛んでいる間にラベルが薄くなり、向かっている向きの強調も消えるので、押せなくするだけにする。
        // 読み上げから押された場合も、`commit` の先頭で止まる
        .allowsHitTesting(!isInteractionLocked)
    }

    /// 手前のカードを `direction` の向きに飛ばし、飛び終わってからジャンルを付ける。
    /// 先に付けると `@Query` からその記録がすぐ消え、飛んでいる途中のカードが消えてしまうため。
    /// `start` はスワイプで離した瞬間の位置。そこから飛ばすことで、見た目が途切れない（ラベルを押したときは 0）。
    /// `flight` はスワイプで払った勢いの飛び先と時間。ラベルを押したときは nil で、仕分けの向きにまっすぐ飛ばす。
    /// `pause` は、スタンプとラベルの強調を出してから飛び始めるまでの時間（おまかせだけ。手のスワイプ・ラベルは 0）
    private func commit(
        _ direction: SwipeDirection,
        from start: CGSize = .zero,
        flight: (offset: CGSize, duration: TimeInterval)? = nil,
        pause: Duration = .zero,
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
        guard pause > .zero else {
            fly(record, direction, flight: flight, screenSize: screenSize)
            return
        }
        Task {
            try? await Task.sleep(for: pause)
            fly(record, direction, flight: flight, screenSize: screenSize)
        }
    }

    /// 画面の外へ飛ばし、飛び終わったらジャンルを付ける（`commit` の後半）。
    private func fly(
        _ record: Record, _ direction: SwipeDirection, flight: (offset: CGSize, duration: TimeInterval)?,
        screenSize: CGSize
    ) {
        // 止めの間に状態が戻されていたら（画面が閉じたなど）、飛ばさない・保存しない
        guard flyingRecordID == record.id else { return }
        let animation: Animation = flight.map { .linear(duration: $0.duration) } ?? .easeIn(duration: 0.25)
        withAnimation(animation) {
            flyOffset = flight?.offset ?? direction.offscreenOffset(in: screenSize)
        } completion: {
            // 位置は、`@Query` から飛ばしていた記録が消えたとき（`onChange(of: records.map(\.id))`）に戻す（`resetAfterCommit`）。
            // ここで一緒に戻すと、`@Query` の更新が遅れたとき、仕分けた写真が真ん中に一瞬戻って見える
            onSort(record, direction.genre)
            // 保険：記録が並びから消えず `onChange` が来ないと `isCommitting` が残り、✕ も効かず抜けられなくなる
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
