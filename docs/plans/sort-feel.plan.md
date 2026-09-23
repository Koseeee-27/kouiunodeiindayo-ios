# 実装計画: 仕分けの手触り（大きなカード・縁のラベル・払った勢い・振動・スタンプ・せり上がり）

## 概要

#16 で作った仕分け画面（`Features/Sort/`）の見た目と手触りを直す。カードを画面いっぱいに広げ、4方向のラベルをカードの縁に重ねる。払った勢いで飛ばし、振動・スタンプ・次のカードのせり上がりを足す。対応する Issue：#36。対応する機能：`docs/requirements.md` の機能4（ジャンルを付ける）。

要素・操作は `docs/screen-design.md` の「仕分け」が正。この Issue はラベルの位置と手触りだけを変え、要素と操作は変えない。スワイプを自作する決定は `docs/adr/0005-swipe-ui.md`。

## 前提・確認事項

- 前の計画は `docs/plans/sort.plan.md`（#16）。特に「実装して分かったこと」は、この Issue でも守る（写真の当たり判定を外す・カードは id の `ForEach`・位置の戻しは `onChange(of: records.first?.id)` と 300ms の保険・`@GestureState` と `@State` の分け方など）
- データ層・`SortView` の外から見た形（`SortView()`・`SortView(dragOffset:)`）は変えない。ホーム（`HomeView`）とカメラ（`CameraFlowView`）の呼び出しはそのまま動く
- `project.pbxproj` は触らない（同期フォルダにファイルを置くだけ）。効果音と「う、うまい」のアニメーションは #22、色・フォントは #23。スタンプの見た目は仮
- 決めたこと（2026-09-23 にこうせいと確認済み）
  - **写真の縦横比は絶対に崩さない。** カードの枠が縦長になっても、写真は引き伸ばさない。写真全体が見えるよう `scaledToFit` で真ん中に置き、余った部分は同じ写真を `scaledToFill` + ぼかしで敷く（横長の写真を縦長の枠で大きく切り抜くと見づらいため）。`.resizable()` の後には必ず `scaledToFit` / `scaledToFill` を付ける
  - **ラベルはカードと一緒に動かさない。** カードの重なりの枠の上・下・左・右の縁（真ん中）に固定し、その下をカードが動く。**ラベルは常にカードより手前に描く**（#16 では飛んでいくカードがラベルを隠し、スワイプ中にどのラベルか分からなかった）。スワイプ中は向かっている向きのラベルを強調し（拡大・色を付ける）、ほかのラベルも何のラベルか読める濃さ（`opacity` 0.6 程度）に留める
  - **振動**：「離せば仕分けになる距離（`commitDistance`）」を超えた瞬間に `.impact(weight: .light)`、仕分けが決まった瞬間（スワイプでもラベルでも）に `.impact(weight: .medium)`。戻して超え直したらもう一度鳴る。実機で確認して調整する
  - **後ろのカード**：手前のカードの下端を 10pt ほど上げ、その隙間から後ろのカードの下端を見せる（`docs/screen-design.md`「後ろに次の写真が少し見えて」）
  - **文字サイズ最大**：上のラベルと右上の「う、うまい」が同じ上の縁に並ぶ。まず表示を確かめ、重なるなら、ラベルと「う、うまい」だけ `.dynamicTypeSize(...)` で上限を付ける
- 実装して分かったこと（2026-09-23。下のステップとの違い）
  - **ぼかした地と写真は、同じ `ZStack` に入れず別々の `overlay` にする**：`ZStack` に入れると、`scaledToFill` の地（カードからはみ出す大きさ）が `ZStack` の大きさになり、`scaledToFit` の写真もその大きさで広がる。結果、写真が地と同じだけ切り抜かれ、ぼかしも完全に隠れて #16 と同じ見た目になった。灰色の地 → `overlay` でぼかした地 → `overlay` で写真、の順に重ねると、どちらもカードの大きさを基準にする。ぼかしは `.blur(radius: 30, opaque: true)`（縁が透けて灰色が見えないように）
  - **プレビュー用の横長の写真を足した**：単色の画像では歪みもぼかしも見えないので、`SortPreviewData.makeLandscapeContainer()` に丸と格子を描いた横長の画像（1600×1200）を足した。丸がつぶれていなければ縦横比が保たれている。`SortView` の `#Preview("横長の写真")` と、`SortCardView` 単体の `#Preview("横長の写真")` で見る
  - **後ろのカードは、手前と同じ枠のまま下端を基準に縮める**：`scaleEffect(0.92, anchor: .bottom)` + `offset(y: 10)`。枠を別にすると、手前に来たときに大きさが変わって跳ねる。せり上がりは「大きさ → 1.0、ずらし → 0」の2つを変えるだけ。定数は `SwipeDirection.backCardScale`・`backCardPeek`（手触りの定数と同じファイルに置いた）
  - **ラベルは `cardStack` の `overlay` にし、後ろのカード用の下の隙間（10pt）はその外側で空ける**：隙間の内側に置くと、下のラベルが手前のカードの縁ではなく後ろのカードの縁に来る
  - **強調中のラベルの文字は白にした**：`.glassEffect(.regular.tint(.accentColor))` の青い地に黒い文字が読みにくかったため。見た目は #23 で見直す
  - **スタンプはカードの真ん中ではなく、上寄り（上端から 96pt）に置いた**：真ん中だと、左右に動かしたときにスタンプが左右のラベル（縦の真ん中に固定）の下に潜って読めなかった。ラベルは常に手前に描く決まりなので、スタンプのほうを避けた
  - **振動のきっかけ（`pendingCommit`）は、飛んでいる間は nil にする**：ラベルを押したとき、飛ぶ位置（`flyOffset`）が `commitDistance` を超えた瞬間に軽い振動まで鳴ってしまうため。決まった瞬間の振動（`commitCount`）だけが鳴る
  - スタンプの濃さと後ろのカードのせり上がりの割合は `SwipeDirection.progress(for:)`（主な向きに進んだ距離 ÷ `commitDistance`、0〜1）で共通にした
  - プレビュー「ドラッグ途中」の値は、スタンプが濃く見えるよう右 85・上 10 にした
  - **文字サイズは、ラベルと「う、うまい」だけ `.dynamicTypeSize(...DynamicTypeSize.xLarge)` で上限を付けた**：最大（AX 5）で「食べ物」と「う、うまい」、「飲み物」と「デザート」が重なって隠れた（`.verification/36/04a-…`）。プレビューで見ると X Large までは重ならず、XX Large で触れ始める。既定の Large でも上の段の隙間は小さいので、「う、うまい」の置き場所は #23 で見直す余地がある。✕・残り枚数・スタンプには上限を付けていない
  - **飛んでいる間のラベルは `.disabled` ではなく `.allowsHitTesting(false)` で止める**：`.disabled` だとラベルが薄くなり、向かっている向きの色の強調も消えた（#16 の「う、うまい」と同じ理由）。読み上げから押された場合も `commit` の先頭の `guard !isCommitting` で止まる
  - 右上に斜め（ほぼ 45 度）に払うと、縦の移動量がわずかに大きければ「上（食べ物）」になる。向きは #16 と同じく移動量の縦横の大きいほうで決めており、飛ぶ向き（払った向き）とは別。実機で気になれば相談する

## ステップ

1. `Kouiunodeiindayo/Features/Sort/SortCardStackView.swift` — 新規。`SortView` から「カードの重なり・ラベル・ドラッグ・飛ばす処理」を移す（この時点では見た目を変えない）
   - 移すもの：`cardStack`、`dragGesture`、`genreLabel`、`commit`、`resetAfterCommit`、`dragTranslation`・`flyOffset`・`flyingRecordID`・`previewDragOffset`・`cardOffset`、`onChange(of: records.first?.id)`
   - 受け取るもの：`let records: [Record]`（`SortView` の `@Query` の結果をそのまま渡す。先頭2件だけ使う）、`@Binding var isCommitting: Bool`（✕ を無効にするため `SortView` と共有）、`let previewDragOffset: CGSize`、`let onSort: (Record, Genre) -> Void`（`store.setGenre`）、`let onToggleFavorite: (Record) -> Void`
   - 画面の大きさ（飛ばす先の計算）は、`SortCardStackView` の中の `GeometryReader` で取る
   - `SortView` に残すのは `@Query`・上の行（✕ と「あと n 枚」）・空のとき・`dismiss`・`wasEmptyAtOpen`
   - ファイル先頭のコメントに役割を書く／確認：ビルドが通り、`SortView` の4つのプレビューが変わらない
2. `Kouiunodeiindayo/Features/Sort/SortCardView.swift` — 写真の出し方を変える
   - 地：同じ写真を `.resizable().scaledToFill()` + `.blur(radius: 30)` 程度（読めていない間は今の灰色の地）
   - 手前：同じ写真を `.resizable().scaledToFit()`。写真全体が見え、縦横比は元のまま
   - どちらも `.allowsHitTesting(false)`。読み込みは今の `.task(id:)` の1回だけ（`UIImage` を2か所で使うだけで、2回読まない）
   - 右上の「う、うまい」は今のまま（大きさの上限はステップ 7 の確認次第）／確認：プレビューで縦長・横長の写真が歪まず全体が見える（横長のサンプルが無ければ `SortPreviewData` に足す）
3. `SortCardStackView.swift` / `SortView.swift` — カードを大きくする
   - `.aspectRatio(3 / 4, contentMode: .fit)` をやめ、幅は左右 16pt を空けていっぱい、高さは上の行の下から画面の下（セーフエリアの内側）まで
   - 手前のカードは下を 10pt ほど空け、後ろのカード（大きさ 0.92）の下端がそこからのぞくように、後ろのカードを下へずらす
   - `SortView` の `.padding()` は左右 16pt に合わせる／確認：プレビューで上下の余白が目立たない
4. `SortGenreLabelView.swift` / `SortCardStackView.swift` — ラベルを縁に重ねる
   - ラベルはカードの重なりの `overlay` に4つ置く（上：`.top`、下：`.bottom`、左：`.leading`、右：`.trailing`）。縁から 12pt ほど内側（16pt の余白しかないので、縁をまたぐと画面の外にはみ出す）
   - `overlay` はカードの `ZStack` より手前にあるので、飛んでいくカードにも隠れない。ラベルの `zIndex` の工夫は要らなくなる
   - チップの見た目：`Label(genre.title, systemImage: genre.systemImage)` を `.font(.subheadline.weight(.semibold))`、`.padding(.horizontal, 12).padding(.vertical, 8)`、`.glassEffect(.regular, in: .capsule)`（iOS 26 の Liquid Glass）。左右もアイコンと文字を横に並べる（`isVertical` は消す）
   - 強調：向かっている向きは `scaleEffect` 1.15 + `.glassEffect(.regular.tint(.accentColor), in: .capsule)` など色を付ける。ほかは `opacity` 0.6。`lineLimit(1)`・`minimumScaleFactor` は残す
   - 押すと仕分け、`accessibilityLabel`「\(genre.title)にする」は今のまま／確認：プレビュー「ドラッグ途中」で、4つのラベルが全部読め、右のラベルが強調されている
5. `SwipeDirection.swift` / `SortCardStackView.swift` — 払った勢いで飛ばす
   - `onEnded` で `value.velocity`（離した瞬間の速さ。pt/秒）を受け取る
   - 飛ぶ向き：速さのベクトルが仕分けの向きに正の成分を持ち、速さが `flingMinSpeed`（例 300pt/秒）以上なら、そのベクトルの向き（斜めも可）に画面の外まで。そうでなければ仕分けの向きの軸にまっすぐ
   - 飛ぶ時間：残りの距離 ÷ 速さを `flyMinDuration`（0.12 秒）〜`flyMaxDuration`（0.35 秒）に収める。アニメーションは `.linear(duration:)`（離した瞬間の速さのまま飛ぶ）
   - ラベルを押したときは今のまま（まっすぐ、`.easeIn(duration: 0.25)`）
   - 計算は `SwipeDirection` に `static func flight(from translation: CGSize, velocity: CGSize, direction: SwipeDirection, in size: CGSize) -> (offset: CGSize, duration: TimeInterval)` のような関数で置き、定数も同じファイルにまとめる／確認：ビルド。手触りは実機
6. `SortCardStackView.swift` — 振動・スタンプ・せり上がり
   - 振動：`SwipeDirection` に `static func pendingCommit(for translation: CGSize) -> SwipeDirection?`（主な向きに `commitDistance` 以上進んでいればその向き）を足す。`.sensoryFeedback(trigger: pendingCommit) { _, new in new != nil ? .impact(weight: .light) : nil }`。仕分けが決まった瞬間は、`commit` で増やすカウンタ（`@State commitCount`）を trigger にして `.impact(weight: .medium)`
   - スタンプ：新規 `SortStampView.swift`（ジャンル名を太字・枠線付き・少し傾けたハンコ風。色は仮）。手前のカードの真ん中に重ね、カードと一緒に動く。濃さ ＝ 主な向きに進んだ距離 ÷ `commitDistance`（0〜1）。飛んでいる間は、飛ばしている向きのジャンルを濃さ 1 で出す（ラベルを押したときも出る）。飛ばしている向きは `@State flyingDirection` に控える。コメントに「見た目は仮。#23 で合わせる」
   - せり上がり：後ろのカードの大きさは `0.92 + 0.08 × 進んだ割合`（ドラッグ中に少しずつ近づく）。仕分けが決まった瞬間に `withAnimation(.spring(duration: 0.35, bounce: 0.3))` で 1.0・ずらし 0 にする（`@State isNextRising`）。手前に来た時点ですでに 1.0 なので、切り替えで跳ねない。`resetAfterCommit` で `isNextRising = false`（アニメーション無し）
   - プレビュー「ドラッグ途中」の値を、スタンプが見える程度（`commitDistance` 近く）に直してよい／確認：プレビューでスタンプと、後ろのカードが少し大きくなっているのが見える
7. `docs/architecture.md` — 「フォルダ構成」の `Sort/` に `SortCardStackView.swift`（カードの重なり・縁のラベル・ドラッグと飛ばす処理）と `SortStampView.swift`（ドラッグ中のスタンプ。見た目は仮）を足し、`SortView.swift` の説明を「上の行・残り枚数・抜ける手段」に直す。`SortGenreLabelView` の説明を「縁に重ねるチップ」に直す／確認：文書だけ
8. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/36/` に残す（git には入れない）
   - プレビュー：`preview-SortView-複数枚.png`、`preview-SortView-ドラッグ途中.png`（ラベル4つ・スタンプ・後ろのカード）、横長の写真のカード
   - シミュレータ：`01-仕分け-カードが大きい.png`、`02-ラベルを押す-次へ.png`、`03-文字サイズ最大.png`（「う、うまい」とラベルが省略されず、重ならない）
   - `notes.md` に写真ごとの「操作」と「見るところ」を表で書く（#16 と同じ形）
9. 実機での確認（こうせいが行う）：払う速さで飛び方が変わるか、途中で離すと戻るか、振動のタイミング、スタンプの濃さ、せり上がり、写真が歪まず見やすいか。気になる点は `SwipeDirection.swift` の定数で直す

## リスク

- **次のカードが画面の外から飛んでくる**：せり上がりのアニメーションが位置の戻しにまで効くとこう見える。バネのアニメーションは `isNextRising` の変更だけに付け、位置（`flyOffset`）の戻しは今と同じくアニメーション無しの `Transaction` で行う
- **ラベルの上でドラッグを始めたとき**：ラベルはボタンなので、カードは動かない。チップは小さいので許容する。実機で気になれば相談する
- **ぼかしの負荷**：ドラッグ中に毎フレーム `blur` を描き直すと重くなることがある。もたつくなら、ぼかした画像を読み込み時に1回だけ作るか、`.drawingGroup()` を試す
- **`glassEffect` の強調の色**：`tint` の付け方が期待どおりにならなければ、`.background` の色 + `opacity` で代用してよい（Liquid Glass はトーンが決まったら #23 で見直す）
- **`.sensoryFeedback` がシミュレータで鳴らない**：振動は実機でしか確かめられない

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- プレビューとシミュレータで：カードが幅いっぱい、上下の余白が目立たない。写真が歪まない。ラベル4つがカードの縁に重なって読め、押すと仕分けできる。ドラッグ途中でスタンプが出る。文字サイズ最大で省略・重なりが無い
- 実機での確認：**要る**（ステップ 9）。実機で確かめるまで Issue を閉じない
