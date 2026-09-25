import SwiftData
import SwiftUI

/// 開いたときの画面。下タブ（左からカメラ／ホーム／一覧）と、ホーム⇄一覧の横スワイプを持つ。
/// 並びと行き来の決まりは `docs/screen-design.md` の「ナビゲーション」が正。
struct RootView: View {
    /// ページャーの現在位置。`.home` か `.list` だけが入る。
    @State private var page: RootTab = .home
    /// カメラのカバーが出ているか。開いたときの画面の設定で変わるので `init` で決める。
    @State private var isCameraShown: Bool
    /// 下タブの高さと、画面の下のセーフエリア（ホームインジケーター）。ページャーのスクロールの下余白に使う
    @State private var tabBarHeight: CGFloat = 0
    @State private var bottomSafeArea: CGFloat = 0

    /// 引数を省くと、設定（`UserDefaults`）の「開いたときの画面」に従う。
    /// `.onAppear` で切り替えると最初の1フレームがホームになってしまうので、`init` で決める。
    init(startTab: StartTab = .stored) {
        _isCameraShown = State(initialValue: startTab == .camera)
    }

    var body: some View {
        // 下タブのガラスの下まで、ホーム・一覧の中身が広がって透けて見えるようにする。
        // `safeAreaInset` だと、ページャーがバーの上で終わり、バーの下に地の帯ができて透けない
        ZStack(alignment: .bottom) {
            // 指についてくる横スワイプにするため、ホームと一覧はページャーに載せる
            TabView(selection: $page) {
                HomeView { select(.camera) }
                    .tag(RootTab.home)
                RecordListView()
                    .tag(RootTab.list)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // ページャーを画面の下まで広げる。スクロールの末尾がバーに隠れないよう、バーの分だけ下に余白を足す
            .ignoresSafeArea(.container, edges: .bottom)
            .contentMargins(.bottom, tabBarHeight + bottomSafeArea, for: .scrollContent)
            // `onSelect: select` と関数名だけを渡すと、Xcode 27 のプレビューがビルドに失敗する
            // （`ambiguous use of '__designTimeSelection'`）。クロージャで包むと通る
            RootTabBar(selected: isCameraShown ? .camera : page) { tab in
                select(tab)
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { tabBarHeight = $0 }
        }
        // ページャーはセーフエリア（ステータスバー・下タブの周り）まで地を広げないので、ここでも地を敷く
        .background(Theme.background)
        .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.bottom) { bottomSafeArea = $0 }
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
