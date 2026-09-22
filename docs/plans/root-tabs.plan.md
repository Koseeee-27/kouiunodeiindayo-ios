# 実装計画: RootView と下タブ（カメラ／ホーム／一覧）

## 概要

`App/RootView.swift` を、下タブ3つ（左からカメラ／ホーム／一覧）を持つ本物の入口に置き換え、`Features/` に5つの仮ビューを置く。対応する Issue：#11。対応する機能：画面設計「ナビゲーション」と、機能25（開いたときの画面の設定値の読み込み）。

画面の並びと行き来の決まりは `docs/screen-design.md` の「ナビゲーション」、設定値のキーは `docs/data-model.md` の「設定値」が正。以降の画面の Issue（#12〜#16）は、この計画で置く仮ビューを本物に差し替える。

## 前提・確認事項

- データ層（#10）はマージ済み。`RootView` の今の中身（`DataLayerDebugView`）は「本物の RootView の Issue で丸ごと置き換える」前提で置かれたもの
- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、`Features/` にフォルダとファイルを置くだけで Xcode が認識する
- `Design/Theme.swift` はまだ無い（#23）。タブの文言・アイコンは標準の部品（SF Symbols）のまま置き、色・フォントは Theme ができてから当てる
- 実機での確認は要らない（Issue の記載どおり）。スワイプは「指についてきて、離すと吸い付く」ことをシミュレータで確かめる
- 決めたこと（2026-09-23 にこうせいと確認済み。迷ったら戻す先）
  - **下タブは自作する**（`RootTabBar`）。iOS 標準の `TabView` の下タブは、タブ同士を指で滑らせて行き来できない。ホーム⇄一覧を「指についてくる」横スワイプにするため、ホームと一覧は `TabView` の `.page` スタイル（横にめくるページャー。`.tabViewStyle(.page(indexDisplayMode: .never))`）に載せ、下のバーは自分で描く
  - バーの見た目は iOS 26 の Liquid Glass（`glassEffect(_:in:)`。Apple の公式ドキュメントで存在を確認済み：`nonisolated func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View`）。作り込みは Theme（#23）以降。ここでは `HStack` にボタン3つを並べて `.glassEffect()`（既定のカプセル）を付けるだけ
  - **カメラは横スワイプでは出さない。バーのボタンだけ**。MVP のカメラは iPhone 標準のカメラ画面（`UIImagePickerController`）で、下から出るモーダル（画面を覆う一時的な画面）にしかできない。横に滑らせて出す手段が無い。ワークスペースの `open-issues.md` の未決事項「横スワイプでカメラを全画面に出せるか」は「出せない。ボタンだけ」で決着。Issue #11 にコメントを書く
  - タブの状態は2つに分ける。`page: RootTab`（ページャーの現在位置。`.home` か `.list` だけ入る）と `isCameraShown: Bool`（カメラのボタンが押されているか）。バーで選択中に見せるのは `isCameraShown ? .camera : page`。カメラのボタンを押すと `isCameraShown = true`、ホーム・一覧のボタンを押すと `isCameraShown = false` にしてから `page` を書き換える（`withAnimation`）。ページャーの `selection` は `page` に直接結ぶので、ホームで一覧を押すとページがめくれ、スワイプした結果はバーに反映される
  - この骨組みでは、カメラの仮ビューはページャーの上に重ねる（`ZStack`）だけで、バーは隠さない。本物の標準カメラは画面全体を覆うのでバーは自然に隠れる。カメラの仮ビューから戻る手段（キャンセル→ホーム）は #15 で作る
  - 開いたときの画面は `enum LaunchScreen: String { camera, home }`（`App/LaunchScreen.swift`）に持たせる。キー `"launchScreen"` の文字列はこの enum の `static let storageKey` に1か所だけ書く。設定画面（機能25）はこの enum を使って書き込む
  - `RootView` の最初の状態は `init(launchScreen:)` で決める。引数を省くと `UserDefaults` の `launchScreen` を読む。`isCameraShown` は宣言時に初期値を持たせず、`init` で `State(initialValue:)` を渡す（`docs/rules/swift.md` の「宣言時に初期値を持つ `@State` に `init` で代入しない」に反しない書き方）。`page` は宣言時に `.home` を入れ、`init` では触らない。`.onAppear` で切り替える方法は、最初の1フレームがホームになってからカメラに変わるので採らない
  - 仮ビューは「画面名の文字だけ」。型名は `HomeView` / `RecordListView` / `CameraView` / `SortView` / `RecordDetailView`（`docs/architecture.md` の「`〜View`」と「SwiftUI の型と同じ名前を付けない」に従う）
  - `DataLayerDebugView`（記録の件数・サンプル追加・すべて消す）は**消す**。シミュレータで記録を作る手段は、カメラの Issue（#15）で「シミュレータのときは写真ライブラリから選ぶ」逃げ道を入れて確保する（#15 にコメント済み）

## ステップ

1. `Kouiunodeiindayo/App/LaunchScreen.swift` — `enum LaunchScreen: String { case camera, home }`。`static let storageKey = "launchScreen"`、`static var stored: LaunchScreen`（`UserDefaults.standard.string(forKey:)` を読み、無い・知らない文字列なら `.camera`）／確認：ビルド
2. `Kouiunodeiindayo/App/RootTab.swift` — `enum RootTab: CaseIterable { case camera, home, list }`（この順。バーの並び順に使う）。`title`（「カメラ」「ホーム」「一覧」）と `systemImage`（`camera` / `house` / `square.grid.2x2`）の計算プロパティ／確認：ビルド
3. `Kouiunodeiindayo/Features/Home/HomeView.swift`、`Features/List/RecordListView.swift`、`Features/Camera/CameraView.swift`、`Features/Sort/SortView.swift`、`Features/Detail/RecordDetailView.swift` — それぞれ `Text("ホーム")` など画面名だけの `struct` と `#Preview`／確認：各プレビューが出る
4. `Kouiunodeiindayo/App/RootTabBar.swift` — `struct RootTabBar: View`。引数は `selected: RootTab` と `onSelect: (RootTab) -> Void`
   - `HStack` に `RootTab.allCases` の順で `Button` を並べる。中身は `VStack { Image(systemName:); Text(title).font(.caption2) }`。選択中は `.foregroundStyle(.tint)`、それ以外は `.secondary`
   - `HStack` に `.padding` を付けてから `.glassEffect()`（既定のカプセル）。`glassEffect` は見た目に関わる修飾子のあとに付ける（公式ドキュメントの注意）
   - 各ボタンに `accessibilityLabel(title)`、選択中には `.accessibilityAddTraits(.isSelected)`
   - `#Preview` で3つの選択状態を並べる／確認：プレビューで並び順と選択の見た目
5. `Kouiunodeiindayo/App/RootView.swift` — 書き直す（`DataLayerDebugView` は消す）
   - `@State private var page: RootTab = .home`、`@State private var isCameraShown: Bool`（初期値なし）。`init(launchScreen: LaunchScreen = .stored)` で `_isCameraShown = State(initialValue: launchScreen == .camera)`
   - 中身：`ZStack` に、`TabView(selection: $page) { HomeView().tag(RootTab.home); RecordListView().tag(RootTab.list) }.tabViewStyle(.page(indexDisplayMode: .never))` と、`if isCameraShown { CameraView() }` を重ねる
   - `.safeAreaInset(edge: .bottom) { RootTabBar(selected: isCameraShown ? .camera : page, onSelect: select) }`。`safeAreaInset` にするのは、あとで本物のホーム・一覧のスクロールがバーの下まで伸びつつ、末尾がバーに隠れないようにするため
   - `select(_ tab: RootTab)`：`withAnimation` の中で、`.camera` なら `isCameraShown = true`、それ以外なら `isCameraShown = false; page = tab`
   - `#Preview("カメラから開く")` は `RootView(launchScreen: .camera)`、`#Preview("ホームから開く")` は `RootView(launchScreen: .home)`。どちらも `.modelContainer(SampleData.makePreviewContainer())` と `.environment(\.photoStorage, SampleData.photoStorage)` を付ける（以降の画面 Issue がこのプレビューを使うため）／確認：2つのプレビューで、開いたときの画面が違う
6. `docs/architecture.md` の「フォルダ構成」の `App/` に `RootTab.swift`・`RootTabBar.swift`・`LaunchScreen.swift` を1行ずつ足し、「下タブは `RootView` が持つ」の文に「バーは自作（`RootTabBar`）。ホーム⇄一覧は `TabView` の `.page` で横にめくる」を添える／確認：文書だけ
7. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/11/` に残す：`01-起動直後-カメラ.png`、`02-ホームタブ.png`、`03-一覧タブ.png`、`04-ホームから左スワイプ-一覧.png`、`05-launchScreen-home-ホームから開く.png`、`preview-RootTabBar.png`。スワイプ途中（指についてきている瞬間）の写真が撮れれば `04a-スワイプ途中.png` として足す。`launchScreen` の設定は `xcrun simctl spawn booted defaults write <bundle id> launchScreen home` で入れてからアプリを起動し直す（bundle id は `Config/Base.xcconfig` と `Local.xcconfig` から求める）。`notes.md` に操作と見るところを表で書く
8. Issue #11 にコメント：「横スワイプでカメラを全画面に出せるか」の結果（標準カメラはモーダルなので横から出せない。バーのボタンだけにする）と、下タブを自作した理由（指についてくるスワイプのため）
9. `docs/rules/self-review.md` のセルフレビューを回してから PR（`Closes #11`）。ワークスペース側の `open-issues.md` の該当行は、PR がマージされたあとに「決着」として整理する（別リポなので、この PR には含めない）

## リスク

- `TabView(.page)` の中に縦の `ScrollView` を置いたとき（#12・#14）、横スワイプと縦スクロールの取り合い：`UIPageViewController` ベースなので、方向で自動的に振り分けられる。問題が出たらそちらの Issue で見る
- 仕分け画面（#16）の4方向スワイプとページャーの干渉：仕分けはホーム・一覧から別画面として開く（画面を覆う）ので、ページャーには触れない。もし同じ階層に置く設計になったら、そのときに `page` の切り替えを止める仕組みを足す
- `glassEffect` の下に来る内容が薄いと、文字が読みにくい：仮ビューは白地なので問題ない。本物の画面で気になったら `.regular.tint(...)` や Theme で調整する
- 自作バーは標準の下タブが持つ「スクロールで縮む」などの挙動を持たない。要らないので作らない
- `UserDefaults` に `launchScreen` が未設定のときは `.camera` に倒す。`@AppStorage` を `RootView` に置かないので、設定画面で値を変えても開いている画面は変わらない（開き直したときに効く。機能25 の仕様どおり）
- `SortView` / `RecordDetailView` はタブに載らない（ホーム・一覧から開く画面）。この Issue ではファイルを置くだけで、`RootView` からは参照しない

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- `RootView` のプレビュー2つで、「カメラから開く」はカメラ、「ホームから開く」はホームが出ている
- シミュレータで、バーに左からカメラ／ホーム／一覧の順にボタンが並び、押すと切り替わる。ホーム⇄一覧はページがめくれ、バーの選択も追従する
- シミュレータで、ホームを左に引っ張るとページが指についてきて、離すと一覧に吸い付く。一覧を右に引っ張るとホームに戻る。一覧を左、ホームを右に引っ張っても、端で止まる（カメラは出ない）
- `Features/` に `Home` / `List` / `Camera` / `Sort` / `Detail` の5フォルダと仮ビューがある
- `launchScreen` が `home` のとき、ホームから開く
- 実機での確認：不要（Issue の記載どおり）
