import SwiftUI

/// 起動画面（`LaunchScreen.storyboard`）は、アプリの準備が終わるとすぐ消えて短い。
/// そこで、同じ絵を SwiftUI の画面としても出して、一定の時間だけ見せてから、本物の画面に切り替える。
/// 起動画面と同じ見た目（紙色の地に、絵を画面いっぱいに）にして、切れ目が見えないようにする。
struct LaunchSplashGate<Content: View>: View {
    /// 起動画面を出しておく秒数
    static var duration: Duration { .seconds(2) }

    @ViewBuilder let content: () -> Content

    @State private var isSplashShown = true

    var body: some View {
        ZStack {
            // 起動画面が出ている間は、本物の画面を作らない（開いたときの画面の判断も、切り替わってから行う）
            if !isSplashShown {
                content()
            }
            if isSplashShown {
                splash
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: Self.duration)
            withAnimation(.easeOut(duration: 0.3)) {
                isSplashShown = false
            }
        }
    }

    private var splash: some View {
        Theme.background
            .overlay {
                Image("LaunchScreen")
                    .resizable()
                    .scaledToFill()
            }
            .ignoresSafeArea()
            // 起動画面の絵は文字を含むので、読み上げでは、アプリ名として読ませる
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("こういうのでいいんだよ、こういうので。")
    }
}

#Preview {
    LaunchSplashGate {
        Text("本物の画面")
    }
}
