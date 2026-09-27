import SwiftUI

extension View {
    /// 「うまい」のハンコを押したときの演出（機能24）。`isOn` が false → true に変わった瞬間だけ、
    /// 大きく少し傾いた状態からドンと縮んで止まり、同じ形の輪が外に広がって消え、振動して、ハンコを押す音が鳴る。true → false では何もしない。
    /// 音はマナーモードでは鳴らない（`SoundPlayer`）。
    /// 最初に表示したとき（すでに付いている記録を開いたとき）は出さない（`onChange` は最初の表示では呼ばれない）。
    /// 「視差効果を減らす」がオンのときは、動きと輪を出さず、振動と音だけにする。
    /// 押せるかどうかは見ない（おまかせ中などに押せなくするのは、呼ぶ側のボタンの決まりのまま）。
    func stampPress(isOn: Bool) -> some View {
        modifier(StampPressModifier(isOn: isOn))
    }
}

/// 演出の 1 コマの値
struct StampPressValues {
    var scale: CGFloat = 1
    var tilt = Angle.zero
    var ringScale: CGFloat = 1
    var ringOpacity: Double = 0
}

/// 押してからの時間ごとの値。`keyframeAnimator` とプレビューのコマ送り（`KeyframeTimeline`）で同じものを使う
enum StampPressKeyframes {
    static let initial = StampPressValues()

    @KeyframesBuilder<StampPressValues>
    static var tracks: some Keyframes<StampPressValues> {
        KeyframeTrack(\.scale) {
            // 押した瞬間に大きくして、弾みを付けて縮み、少し小さくなってから 1 倍に戻る
            MoveKeyframe(Theme.stampPressScale)
            SpringKeyframe(Theme.stampPressUndershoot, duration: Theme.stampPressDuration * 0.6, spring: .snappy)
            SpringKeyframe(1, duration: Theme.stampPressDuration * 0.4, spring: .bouncy)
        }
        KeyframeTrack(\.tilt) {
            MoveKeyframe(Theme.stampPressTilt)
            SpringKeyframe(.zero, duration: Theme.stampPressDuration, spring: .snappy)
        }
        KeyframeTrack(\.ringScale) {
            MoveKeyframe(1)
            CubicKeyframe(Theme.stampPressRingScale, duration: Theme.stampPressRingDuration)
        }
        KeyframeTrack(\.ringOpacity) {
            MoveKeyframe(Theme.stampPressRingOpacity)
            LinearKeyframe(0, duration: Theme.stampPressRingDuration)
        }
    }

    /// プレビューのコマ送り用。押してから `time` 秒のときの値
    static func values(at time: Double) -> StampPressValues {
        KeyframeTimeline(initialValue: initial) { tracks }.value(time: time)
    }
}

private struct StampPressModifier: ViewModifier {
    let isOn: Bool
    /// 付けた回数。振動のきっかけ
    @State private var pressID = 0
    /// 動きのきっかけ。「視差効果を減らす」がオンのときは増やさない（振動だけにする）
    @State private var motionID = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: StampPressKeyframes.initial, trigger: motionID) { view, values in
                view
                    // 輪は絵と同じ大きさの角丸の四角を、絵の外側へ広げながら消す
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.stampPressRingCornerRadius)
                            .strokeBorder(Theme.accent, lineWidth: Theme.stampPressRingLineWidth)
                            .scaleEffect(values.ringScale)
                            .opacity(values.ringOpacity)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .scaleEffect(values.scale)
                    .rotationEffect(values.tilt)
            } keyframes: { _ in
                StampPressKeyframes.tracks
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: pressID)
            .onAppear {
                SoundPlayer.prepare(.stampPress)
            }
            .onChange(of: isOn) { old, new in
                // 付けたときだけ。外すときは何もしない
                guard !old && new else { return }
                pressID += 1
                SoundPlayer.play(.stampPress)
                if !reduceMotion {
                    motionID += 1
                }
            }
    }
}

/// 押すたびに付け外しする（キャンバスの Live で動きを見る）
private struct StampPressPreview: View {
    @State private var isOn = false

    var body: some View {
        VStack(spacing: 48) {
            Button {
                isOn.toggle()
            } label: {
                Image(.umaiBadge)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Theme.detailFavoriteBadgeWidth)
                    .stampPress(isOn: isOn)
                    .opacity(isOn ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            Text(isOn ? "付いている（押すと外す）" : "付いていない（押すと付ける）")
                .font(Theme.font(.footnote))
        }
    }
}

#Preview("押すたびに付け外し") {
    StampPressPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
}

/// 押してからのコマ送り（静止画で動きを見る）。仕分けの「う、うまい」と、詳細の「うまい」。3 コマずつ 2 段に並べる
private struct StampPressFramesPreview: View {
    static let times: [Double] = [0, 0.05, 0.1, 0.15, 0.25, 0.35]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            frames(image: .umaiStamp, baseTilt: Theme.sortFavoriteTilt, title: "仕分け（元の傾きつき）")
            frames(image: .umaiBadge, baseTilt: .zero, title: "詳細")
        }
        .padding()
    }

    private func frames(image: ImageResource, baseTilt: Angle, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.font(.headline, bold: true))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(Self.times, id: \.self) { time in
                    let values = StampPressKeyframes.values(at: time)
                    VStack(spacing: 4) {
                        Image(image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.stampPressRingCornerRadius * 0.5)
                                    .strokeBorder(Theme.accent, lineWidth: Theme.stampPressRingLineWidth)
                                    .scaleEffect(values.ringScale)
                                    .opacity(values.ringOpacity)
                            }
                            .scaleEffect(values.scale)
                            .rotationEffect(values.tilt)
                            .rotationEffect(baseTilt)
                            .frame(width: 100, height: 80)
                        Text(verbatim: String(format: "%.2f 秒", time))
                            .font(Theme.font(.caption2))
                    }
                }
            }
        }
    }
}

#Preview("コマ送り（押してから 0〜0.35 秒）") {
    StampPressFramesPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
}
