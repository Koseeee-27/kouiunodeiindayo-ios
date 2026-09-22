import SwiftData
import SwiftUI

/// 開いたときの画面。下タブ（左からカメラ／ホーム／一覧）と、ホーム⇄一覧の横スワイプを持つ。
/// 並びと行き来の決まりは `docs/screen-design.md` の「ナビゲーション」が正。
struct RootView: View {
    /// ページャーの現在位置。`.home` か `.list` だけが入る。
    @State private var page: RootTab = .home
    /// カメラのボタンが押されているか。開いたときの画面の設定で変わるので `init` で決める。
    @State private var isCameraShown: Bool

    /// 引数を省くと、設定（`UserDefaults`）の「開いたときの画面」に従う。
    /// `.onAppear` で切り替えると最初の1フレームがホームになってしまうので、`init` で決める。
    init(launchScreen: LaunchScreen = .stored) {
        _isCameraShown = State(initialValue: launchScreen == .camera)
    }

    var body: some View {
        ZStack {
            // 指についてくる横スワイプにするため、ホームと一覧はページャーに載せる
            TabView(selection: $page) {
                HomeView()
                    .tag(RootTab.home)
                RecordListView()
                    .tag(RootTab.list)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if isCameraShown {
                CameraView()
            }
        }
        // safeAreaInset にするのは、ホーム・一覧のスクロールがバーの下まで伸びつつ、末尾がバーに隠れないようにするため
        .safeAreaInset(edge: .bottom) {
            RootTabBar(selected: isCameraShown ? .camera : page, onSelect: select)
        }
    }

    private func select(_ tab: RootTab) {
        withAnimation {
            if tab == .camera {
                isCameraShown = true
            } else {
                isCameraShown = false
                page = tab
            }
        }
    }
}

#Preview("カメラから開く") {
    RootView(launchScreen: .camera)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("ホームから開く") {
    RootView(launchScreen: .home)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
