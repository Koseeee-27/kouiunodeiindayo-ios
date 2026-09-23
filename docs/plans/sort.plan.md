# 実装計画: 仕分け（4方向スワイプとラベルでジャンル、「う、うまい」でお気に入り）

## 概要

`Features/Sort/SortView.swift` の仮ビューを、本物の仕分け画面に置き換える。写真のカードを `DragGesture` で4方向にスワイプ（またはラベルを押す）してジャンルを付け、写真の右上の「う、うまい」でお気に入りを付け外しする。対応する Issue：#16。対応する機能：機能3（仕分け待ち）、機能4（ジャンルを付ける）、機能5（お気に入りを付ける）。

要素・操作・状態は `docs/screen-design.md` の「仕分け」、スワイプを自作する決定は `docs/adr/0005-swipe-ui.md` が正。この計画はそれをファイルと関数に落としたもの。

## 前提・確認事項

- #10（データ層）・#11（RootView と下タブ）・#15（カメラ）はマージ済み。仕分けは今、カメラのカバー（`fullScreenCover`）の中で `CameraFlowView` が `step = .sort` のときに出す。閉じるのは `dismiss()`（カバーが閉じ、`RootView` の `onChange(of: isCameraShown)` でホームへ）
- 書き込みは `RecordStore.setGenre(_:for:)` と `RecordStore.toggleFavorite(_:)` を呼ぶだけ。データ層は変えない
- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- `Design/Theme.swift`（#23）はまだ無い。色・フォントは標準のまま。効果音と「う、うまい」のアニメーション（機能24）は #22。初回の操作ガイド（機能16）はこの Issue では作らない
- 決めたこと（2026-09-23 にこうせいと確認済み。迷ったら戻す先）
  - **出す順番は、仕分け待ちを新しい順に読む `@Query` の並びそのまま。** 今のカードは `records.first`。撮った直後の1枚は `takenAt = .now` なので一番新しく、何もしなくても「今撮った1枚 → 溜まっている写真を新しい順」になる。開いた瞬間の並びを固定（スナップショット）する形は、仕分け中に記録が増えないので採らない。残り枚数は `records.count`
  - **「仕分けで下タブを隠すか」は、この Issue では決めない。** 仕分けが出るのはカメラのカバーの中だけで、下タブは最初から隠れている。下タブを出した状態は、ホームの入口（#14）ができるまで試せない。Issue #16 には「カバーの中では隠れていて、スワイプとの干渉なし。出すかどうかは #14 で入口の開き方と一緒に決める」とコメントする
  - **ジャンルの表示名とアイコンは `Data/Genre.swift` に持たせる。** 詳細での付け直し（#19）でも使うため。`RootTab` に文言とアイコンを持たせている形に合わせる
  - **スワイプのしきい値は `SwipeDirection.swift` の定数1か所にまとめる**（実機で調整するため）。初期値は下のステップ 2
- 実装して分かったこと（2026-09-23。下のステップとの違い）
  - **写真の当たり判定を外した**：`scaledToFill` の写真は、切り抜いてもはみ出した部分の当たり判定が残る。カードを `zIndex` で手前にしているので、横長の写真だと左右のラベルが押せなかった。写真の `Image` に `.allowsHitTesting(false)` を付けた
  - **左右のラベルは、アイコンの下に文字を置く**（文字は横書きのまま）。カードの幅を取らないため
  - **`SortView` に `init(dragOffset:)` を足した**：シミュレータの合成操作では指を置いたままの状態を撮れないので、プレビュー「ドラッグ途中」で `dragOffset` を固定して見る。`CameraFlowView` の `init(step:)` と同じ形
  - **ボタンは `Button { } label: { }` で書く**：`Button(action:)` の形だと、プレビューのビルドで `__designTimeSelection` があいまいというエラーになった
  - **カード2枚は `ForEach` で記録の id ごとに並べる**：後ろと手前を別々に書くと、1枚進むたびに手前のカードが作り直され、写真の読み直しと灰色の地が一瞬出る。id で並べ、手前かどうかで大きさ・位置・ジェスチャーを切り替える
  - **飛び終わったあとの位置の戻しは、`@Query` の先頭が変わったとき（`onChange(of: records.first?.id)`）に行う**：`setGenre` と同時に戻すと、`@Query` の更新が遅れたとき、仕分けた写真が真ん中に一瞬戻って見える
  - **指で動かしている量は `@GestureState`（`dragTranslation`）、飛ばす位置は `@State`（`flyOffset`）に分ける**：`onEnded` だけで戻すと、iOS がジェスチャーを取り消したとき（通知センターなど）にカードがずれたまま止まる。`@GestureState` は取り消しでもバネで 0 に戻る。プレビュー「ドラッグ途中」は `init(dragOffset:)` の値を、指で動かしていないときだけ代わりに使う
  - **位置の戻しには保険を付ける**：`onChange` が来ないと `isCommitting` が残って ✕ も効かなくなるので、`setGenre` の 300ms 後に、まだその記録を飛ばしている状態（`flyingRecordID` が同じ id）なら戻す。`@Query` の先頭で判断すると、値が古いときに続けて飛ばした次の記録を戻してしまう
  - **飛んでいる間は「う、うまい」も押せない**。`.disabled` だと薄い色になり、うまいが付いていないように見えるので、`.allowsHitTesting` で止める
  - **最後の1枚を仕分けたあとは「仕分け待ちはありません」を出さない**：カバーが閉じる間に映るため。開いた時点で0件だったかを控え、0件で開いたときだけ出す

## ステップ

1. `Kouiunodeiindayo/Data/Genre.swift` — 表示用のプロパティを足す
   - `var title: String`：`food` = 食べ物、`drink` = 飲み物、`dessert` = デザート、`noGenre` = なし、`unsorted` = 仕分け待ち
   - `var systemImage: String`（仮）：`food` = `fork.knife`、`drink` = `cup.and.saucer`、`dessert` = `birthday.cake`、`noGenre` = `minus.circle`、`unsorted` = `tray`
   - 既存の `rawValue`・`init(storedValue:)` は変えない／確認：ビルド
2. `Kouiunodeiindayo/Features/Sort/SwipeDirection.swift` — 新規。向きと、手触りの定数をまとめる
   - `enum SwipeDirection: CaseIterable { case up, left, right, down }`
   - `var genre: Genre`：上 = `food`、左 = `drink`、右 = `dessert`、下 = `noGenre`（`docs/screen-design.md` の「仕分け」）
   - `static func direction(for translation: CGSize) -> SwipeDirection?`：縦横の大きいほうを採用。その向きの移動量が `highlightDistance` 未満なら `nil`
   - `static func committed(translation: CGSize, predictedEndTranslation: CGSize) -> SwipeDirection?`：主な向きの移動量が `commitDistance` 以上、または予測位置（`predictedEndTranslation`）がその向きに `flickDistance` 以上なら、その向き。向きは `translation` で決める（払った勢いで逆向きに飛ばないよう、予測位置と移動量の向きが同じときだけ払いとみなす）
   - `func offscreenOffset(in size: CGSize) -> CGSize`：画面外へ飛ばす位置（画面の幅・高さの 1.5 倍ほど）
   - 定数（初期値。実機で調整する）：`commitDistance = 100`、`flickDistance = 250`、`highlightDistance = 20`、傾きは `横の移動量 / 20` 度で最大 `15` 度（`static func rotation(for translation: CGSize) -> Angle`）
   - ファイル先頭のコメントに「手触りの調整はこのファイルの定数を直す」と書く／確認：ビルド
3. `Kouiunodeiindayo/Features/Sort/SortCardView.swift` — 新規。写真1枚のカード
   - 引数：`let record: Record`、`let onToggleFavorite: () -> Void`
   - `@Environment(\.photoStorage)`、`@State private var photo: UIImage?`。`.task(id: record.id) { photo = photoStorage.photo(fileName: record.photoFileName) }` で1回だけ読む。ドラッグ中は毎フレーム `body` が呼ばれるので、`body` の中でファイルを読まない
   - 写真は `Image(uiImage:)` を `.resizable().scaledToFill()` にして角丸でクリップ。読めていない間は `Color.secondary.opacity(0.2)` の地
   - 右上に「う、うまい」の `Button`：付いていないときは半透明（`opacity` 0.4 程度）、付いたら濃い（1.0）。`accessibilityLabel` は「う、うまい」、付いているときは `.accessibilityAddTraits(.isSelected)`
   - 状態（`isFavorite`）は `record` を直接読む（`@Model` なので変更で描き直される）／確認：ステップ 4 のプレビュー
4. `Kouiunodeiindayo/Features/Sort/SortView.swift` — 仮ビューを本物に置き換える
   - 仕分け待ちの `@Query` は今のもの（`Genre.unsorted.rawValue` を型のスコープに取り出す形、`\.takenAt` の新しい順）をそのまま使う
   - `@Environment(\.dismiss)`、`@Environment(\.modelContext)`、`@Environment(\.photoStorage)`
   - `@State private var dragOffset: CGSize = .zero`、`@State private var isCommitting = false`
   - 画面の並び：
     - 上の行：左上に ✕ の `Button`（仮の位置。`accessibilityLabel`「仕分けを抜けてホームへ」）、真ん中に「あと \(records.count) 枚」
     - 真ん中：上のラベル → 左のラベル・カードの重なり・右のラベル → 下のラベル
     - カードの重なり：`records.dropFirst().first` があれば、後ろに少し小さく（`scaleEffect` 0.95 程度）・少し下にずらして置く。手前に `records.first` の `SortCardView`
   - 手前のカードの修飾子の順は `.rotationEffect(SwipeDirection.rotation(for: dragOffset))` → `.offset(dragOffset)`（ADR 0005。逆にすると回転した座標系で動く）
   - `DragGesture`：`onChanged` で `dragOffset = value.translation`。`onEnded` で `SwipeDirection.committed(...)` が向きを返せば `commit(direction)`、`nil` なら `withAnimation(.spring) { dragOffset = .zero }`。`isCommitting` の間はジェスチャーを受け付けない
   - ラベル（`SortGenreLabel` を同じファイルの `private struct` で）：`Label(genre.title, systemImage: genre.systemImage)` の `Button`。すべて横書き。ドラッグ中は `SwipeDirection.direction(for: dragOffset)` の向きのラベルを強調（拡大・濃く）し、ほかを薄くする。押すと `commit(direction)`。`accessibilityLabel` は「\(genre.title)にする」
   - `commit(_ direction: SwipeDirection)`：`isCommitting = true` → `withAnimation(.easeIn(duration: 0.25)) { dragOffset = direction.offscreenOffset(in: 画面の大きさ) } completion: { RecordStore(...).setGenre(direction.genre, for: record); dragOffset = .zero; isCommitting = false }`。先に `setGenre` すると `@Query` からその記録がすぐ消え、飛んでいる途中のカードが消えるので、飛び終わってから付ける。画面の大きさは `GeometryReader` で取る。`completion` の時点の `record` は、`commit` の最初に `records.first` を控えたもの
   - 「う、うまい」：`RecordStore(...).toggleFavorite(record)`。写真は次に進まない
   - `.onChange(of: records.isEmpty) { _, isEmpty in if isEmpty { dismiss() } }`：最後の1枚を仕分けたらホームへ
   - 開いた時点で0件のときの保険：`records.first` が無ければ「仕分け待ちはありません」と「ホームへ」の `Button`
   - ファイル先頭のコメントを書き直す（「仮」の記述を消し、どこから開くか・閉じ方・順番の決まりを書く）
   - `#Preview` を3つ：
     - `"1枚"`：`SampleData.makePreviewContainer()`（仕分け待ちは1件）
     - `"複数枚"`：`makePreviewContainer()` に仕分け待ちを2件足したもの（`RecordStore.add` で `SampleData.makeImage` を使う。後ろの写真と「あと 3 枚」の確認用）
     - `"うまいが付いている"`：1枚目に `toggleFavorite` したもの
     - どれも `.environment(\.photoStorage, SampleData.photoStorage)` を付ける。プレビュー用のコンテナを作る処理が長くなるなら `SortView.swift` の末尾に `private` の関数で置く（`SampleData` は他画面と共有なので変えない）／確認：3つのプレビューが出る
5. `Kouiunodeiindayo/Features/Camera/CameraFlowView.swift` — `#Preview("仕分け（仮）")` を `#Preview("仕分け")` に直すだけ。`step` のコメントなどに「仮」が残っていれば直す／確認：ビルド
6. `docs/architecture.md` — 「フォルダ構成」の `Sort/` の下に `SortView.swift`（仕分けの画面。カード・ラベル・残り枚数・抜ける手段）、`SortCardView.swift`（写真1枚のカードと「う、うまい」）、`SwipeDirection.swift`（向き → ジャンル、しきい値・傾きの定数）を足す／確認：文書だけ
7. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/16/` に残す（git には入れない）
   - `preview-SortView-1枚.png`、`preview-SortView-複数枚.png`、`preview-SortView-うまい.png`
   - シミュレータ（起動 → 写真ライブラリから選ぶ → 仕分け）で：
     - `01-写真を選ぶ-仕分け-あと1枚.png`
     - `02-ドラッグ途中-ラベル強調.png`（ドラッグの途中を撮れなければ、プレビューで `dragOffset` を固定した状態で代用してよい）
     - `03-うまいを押す-濃くなる.png`
     - `04-ラベルを押す-ホームへ.png`（最後の1枚なのでホームへ戻る）
     - 2枚溜めてから開き、1枚仕分けて ✕ → `05-抜ける-ホーム.png`。もう一度カメラから1枚選び「あと 2 枚」になる（抜けた分が仕分け待ちに残っている）→ `06-抜けた分が残る-あと2枚.png`
     - `07-文字サイズ最大-仕分け.png`
   - ジャンルが付いたかは、ホーム・一覧がまだ仮なので、`simctl` でアプリのデータの SQLite を読むか、残り枚数が減ることで確かめる。どちらで確かめたかを `notes.md` に書く
   - `notes.md` に写真ごとの「操作」と「見るところ」を表で書く（#15 の `notes.md` と同じ形）
8. 実機での確認（こうせいが行う。AI だけで「確認済み」にしない）。結果は PR の「実機での確認」に書く
   - 4方向のスワイプでジャンルが付き次の写真が出る。途中で離すと戻る
   - 傾き・飛び方・しきい値の手触り（気になれば `SwipeDirection.swift` の定数を直す）
   - ラベルを押しても仕分けられる。「う、うまい」の付け外しができ、押してもスワイプ扱いにならない
   - ✕ で抜けると残りが仕分け待ちに残る。最後の1枚でホームへ
9. `docs/rules/self-review.md` のセルフレビューを回してから PR（`Closes #16`）。Issue #16 に「下タブを隠すか」の結果をコメントする（前提の「決めたこと」）

## リスク

- **`DragGesture` と「う、うまい」ボタンの取り合い**：通常はボタンのタップが勝つ。実機でスワイプ扱いになる・ボタンが効かないなら、ボタンに `.highPriorityGesture(TapGesture())` を付ける
- **飛んでいる間の `@Query` の更新**：`setGenre` は `completion` で呼ぶので、飛んでいる間は `records.first` が変わらない。`completion` の前に画面が閉じた（✕ を押した）場合、ジャンルは付かず仕分け待ちに残る。✕ も `isCommitting` の間は無効にする
- **カードが消えたあと、次のカードが一瞬元の位置に出ない**：`setGenre` と `dragOffset = .zero` を同じ `completion` の中でアニメーション無しに行う。次のカードが手前に来る動きが欲しくなったら #22 で足す
- **ジャンルの保存のタイミング**：`setGenre` は `save()` を呼ばず SwiftData の自動保存に任せる。仕分けた直後に強制終了すると、最後の1枚が仕分け待ちに戻ることがある。実害は小さいのでこの Issue では直さず、起きたら別の Issue にする
- **写真の読み込み**：`photo(fileName:)` はメインスレッドで 2000px の JPEG を読む。カードが変わるたびに1回なので許容する。もたつくなら別 Issue
- **大きな文字サイズ**：ラベルの文字が大きくなるとカードが小さくなる。カードの大きさは残りの領域で決め、ラベルは1行で `minimumScaleFactor` を付ける

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- `SortView` の3つのプレビューで、カード・残り枚数・後ろの写真・「う、うまい」の濃さが出る
- シミュレータで、ラベルを押すとジャンルが付いて次の写真（または最後ならホーム）に進む。「う、うまい」で付け外しでき、写真は進まない。✕ で抜けると、残りが仕分け待ちに残る
- 実機での確認：**要る**（ステップ 8。スワイプの手触りは実機でしか確かめられない）。実機で確かめるまで Issue を閉じない
