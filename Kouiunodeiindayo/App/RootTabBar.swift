import SwiftUI

/// 画面の下に出す自作のタブバー。左からカメラ／ホーム／一覧（`RootTab` の並び順）。
/// 標準の `TabView` の下タブは、タブ同士を指で滑らせて行き来できないため自作する（`docs/plans/root-tabs.plan.md`）。
/// 見た目は iOS 26 標準の下タブに合わせる。バーは Liquid Glass（`glassEffect`）で、選ばれているタブには、ガラスのレンズが乗る。
/// 指を置いたまま横に滑らせても行き来でき、レンズは指について動く（離すと、選ばれているタブへ滑らかに戻る）。
/// ホームと一覧は滑らせている間に切り替わる。カメラはカバーが開いてしまうので、指を離したときにカメラの上にいたときだけ開く。
/// 色は `Theme`（選ばれているタブは tint の墨）。フォント・余白はまだ仮。
struct RootTabBar: View {
    let selected: RootTab
    let onSelect: (RootTab) -> Void

    /// 指のバーの中での横位置。指が離れているときは nil。
    /// `@GestureState` にしておくと、着信などで操作が途中で取り消されても、自動で nil に戻る
    @GestureState private var fingerX: CGFloat?
    /// 今の押している間に、最後に切り替えたタブ。同じタブで何度も切り替えを呼ばないために持つ
    @State private var lastTab: RootTab?
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0

    /// 指が今乗っているタブ。滑らせている間、選択中の見た目をここに追従させる
    private var pressedTab: RootTab? {
        fingerX.map { tab(at: $0) }
    }

    var body: some View {
        // ガラスを2枚（バーとレンズ）重ねるので、`GlassEffectContainer` にまとめる（Apple の公式ドキュメントの推奨）
        GlassEffectContainer(spacing: 0) {
            tabs
                .background(alignment: .leading) { lens }
                // VoiceOver に「タブバー」として読ませる
                .accessibilityAddTraits(.isTabBar)
                // glassEffect は見た目に関わる修飾子のあとに付ける（Apple の公式ドキュメントの注意）
                .glassEffect(.regular, in: .capsule)
        }
        // ガラスの左右に少し余白を残して、横いっぱいに広げる（iOS 26 標準の下タブと同じ広がり方）
        .padding(.horizontal, 16)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                VStack(spacing: 4) {
                    Image(systemName: tab.systemImage)
                    Text(tab.title)
                        .font(Theme.font(.caption2))
                }
                .foregroundStyle(style(isSelected: tab == (pressedTab ?? selected)))
                // 3つのタブを幅いっぱいに均等に分け、押せる範囲も見た目の幅いっぱいにする
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                // タップと滑らせる操作は下の `DragGesture` が受ける。VoiceOver からは、ボタンとして押せるようにする
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selected ? [.isButton, .isSelected] : [.isButton])
                .accessibilityAction {
                    onSelect(tab)
                }
            }
        }
        .padding(.vertical, 10)
        .onGeometryChange(for: CGSize.self, of: \.size) {
            width = $0.width
            height = $0.height
        }
        // 押した瞬間にホーム・一覧が切り替わるのは、滑らせて切り替える操作のため（標準のボタンは離したときに動く）
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($fingerX) { value, state, _ in
                    state = value.location.x
                }
                .onChanged { value in
                    let tab = tab(at: value.location.x)
                    guard tab != lastTab else { return }
                    lastTab = tab
                    // カメラは指を離したときに開く。ここで開くと、滑らせている途中でカバーが出てしまう
                    if tab != .camera {
                        onSelect(tab)
                    }
                }
                .onEnded { value in
                    lastTab = nil
                    // 指をバーの外へ逃がして離したときは、押したことにしない（標準のボタンと同じ）
                    if tab(at: value.location.x) == .camera, isInsideBar(value.location) {
                        onSelect(.camera)
                    }
                }
        )
        // 操作が取り消されて `onEnded` が呼ばれなかったときも、次の押し始めで切り替えを呼べるようにする
        .onChange(of: fingerX == nil) { _, isReleased in
            if isReleased {
                lastTab = nil
            }
        }
    }

    /// 選ばれているタブに乗るガラスのレンズ。指を置くと少し大きくなって、指の位置についてくる
    private var lens: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(.regular, in: .capsule)
            .frame(width: max(cellWidth - Self.lensInset * 2, 0))
            .padding(.vertical, Self.lensInset)
            .scaleEffect(fingerX == nil ? 1 : 1.08)
            .offset(x: lensX)
            // 指についてくる動きと、離したときに戻る動きを、どちらも同じバネで滑らかにする
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: lensX)
            .animation(.spring(duration: 0.25), value: fingerX == nil)
            // 押す操作は、下の `tabs` の `DragGesture` が受ける
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// レンズとバーの端との隙間
    private static let lensInset: CGFloat = 4

    private var cellWidth: CGFloat { width / CGFloat(RootTab.allCases.count) }

    /// レンズの左端。指があれば指の位置（端からはみ出さないよう丸める）、無ければ選ばれているタブの位置
    private var lensX: CGFloat {
        let minX = Self.lensInset
        let maxX = max(width - cellWidth + Self.lensInset, minX)
        if let fingerX {
            return min(max(fingerX - cellWidth / 2 + Self.lensInset, minX), maxX)
        }
        return CGFloat(index(of: selected)) * cellWidth + Self.lensInset
    }

    private func index(of tab: RootTab) -> Int {
        RootTab.allCases.firstIndex(of: tab) ?? 0
    }

    /// 指を離した位置が、バーの中（縦は少し余裕を持たせる）か
    private func isInsideBar(_ point: CGPoint) -> Bool {
        (-Self.releaseSlop...(height + Self.releaseSlop)).contains(point.y)
    }

    private static let releaseSlop: CGFloat = 20

    /// バーの中の横位置から、その下にあるタブを求める。バーの外へはみ出しても、端のタブに丸める
    private func tab(at x: CGFloat) -> RootTab {
        let tabs = RootTab.allCases
        guard width > 0 else { return selected }
        let index = Int(x / width * CGFloat(tabs.count))
        return tabs[min(max(index, 0), tabs.count - 1)]
    }

    /// `.tint` と `Color` は型が違うので、`AnyShapeStyle` で揃えてから渡す。
    private func style(isSelected: Bool) -> AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Theme.textSecondary)
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach(RootTab.allCases, id: \.self) { tab in
            RootTabBar(selected: tab, onSelect: { _ in })
        }
    }
    .padding()
}
