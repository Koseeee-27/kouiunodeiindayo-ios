import SwiftData
import SwiftUI

/// 開いたときの画面。下タブ（左からカメラ／ホーム／一覧）と、ホーム⇄一覧の横スワイプを持つ。
/// 並びと行き来の決まりは `docs/screen-design.md` の「ナビゲーション」が正。
struct RootView: View {
    /// ページャーの現在位置。`.home` か `.list` だけが入る。
    @State private var page: RootTab = .home
    /// カメラのカバーが出ているか。開いたときの画面の設定で変わるので `init` で決める。
    @State private var isCameraShown: Bool

    /// 引数を省くと、設定（`UserDefaults`）の「開いたときの画面」に従う。
    /// `.onAppear` で切り替えると最初の1フレームがホームになってしまうので、`init` で決める。
    init(startTab: StartTab = .stored) {
        _isCameraShown = State(initialValue: startTab == .camera)
    }

    var body: some View {
        // 指についてくる横スワイプにするため、ホームと一覧はページャーに載せる
        TabView(selection: $page) {
            HomeView { select(.camera) }
                .tag(RootTab.home)
            RecordListView()
                .tag(RootTab.list)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // safeAreaInset にするのは、ホーム・一覧のスクロールがバーの下まで伸びつつ、末尾がバーに隠れないようにするため
        .safeAreaInset(edge: .bottom) {
            // `onSelect: select` と関数名だけを渡すと、Xcode 27 のプレビューがビルドに失敗する
            // （`ambiguous use of '__designTimeSelection'`）。クロージャで包むと通る
            RootTabBar(selected: isCameraShown ? .camera : page) { tab in
                select(tab)
            }
        }
        // 標準カメラはモーダルで出す前提の部品なので、埋め込まずカバーで出す。カバーなら下タブも隠れる
        .fullScreenCover(isPresented: $isCameraShown) {
            CameraFlowView()
        }
        // キャンセルと仕分け終了は、どちらもホームへ（`docs/screen-design.md` の「画面のつながり」）。
        // `onDismiss` だと閉じ終わってから切り替わり、一覧から開いたときに一覧が一瞬見える
        .onChange(of: isCameraShown) { _, isShown in
            if !isShown {
                page = .home
            }
        }
    }

    /// カメラのカバーが出ている間はバーが隠れるので、ここに来るのはカバーが閉じているときだけ。
    /// カバーを閉じたあとホームへ戻すのは `onChange(of: isCameraShown)` の1か所に任せる。
    private func select(_ tab: RootTab) {
        withAnimation {
            if tab == .camera {
                isCameraShown = true
            } else {
                page = tab
            }
        }
    }
}

// 以降の画面の Issue は、この2つのプレビューを本物の画面に差し替えて使う
#Preview("カメラから開く") {
    RootView(startTab: .camera)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("ホームから開く") {
    RootView(startTab: .home)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
