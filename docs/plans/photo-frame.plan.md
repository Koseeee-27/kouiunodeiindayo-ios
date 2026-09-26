# 実装計画: 写真に墨のコマ枠を付け、角丸をなくす

## 概要

写真の周りに墨（`Theme.line`）のコマ枠を付け、角丸をなくす。マンガのコマの雰囲気を出すため。デザイン要件書の反映（9/25 決定：ワイヤー集の「見た目の候補」の 1-1 は「中くらい」、1-2 は「角丸なし」）。対応する Issue：#62。対応する機能：無し（見た目の反映）。

## 前提・確認事項

- 対象の写真は 5 か所：ホームの今日の一枚・最近の写真、一覧、仕分けのカード、記録の詳細
- 太さは、主役（今日の一枚・仕分けのカード・記録の詳細）が 2pt、小さい写真（ホームの最近の写真・一覧）が 1.5pt。角丸は付けない
- 写真以外の部品（仕分け待ちの入口・詳細のジャンルボタン・仕分けのラベル・下タブ・スタンプ）は、この Issue では変えない
- `project.pbxproj` は触らない。新しいファイルは同期フォルダに置くだけでよい
- 決めたこと（2026-09-26 にこうせいと確認済み）
  - **仕分けのカードは、3:4 のカードの外周に枠を引く。** 横長の写真の上下の無地も枠の中に入る（カード＝コマ）。横長の写真は、今はカメラしか入口が無いので、ほぼ出ない
  - **記録の詳細は、表示している写真に沿って枠を引く。** 今の表示（`scaledToFit`・枠の箱なし）のまま線を足す。読み込み中の地（3:4）にも同じ枠を付ける
  - **線は内側に引く（`strokeBorder`）。** 写真の外寸・グリッドの間隔は変えない。写真の端が線の太さ分だけ隠れる

## ステップ

1. `Kouiunodeiindayo/Design/Theme.swift` — 写真の枠の太さを足し、線の太さを整理する
   - `static let photoFrameWidthMain: CGFloat = 2`（主役：今日の一枚・仕分けのカード・記録の詳細）
   - `static let photoFrameWidthSmall: CGFloat = 1.5`（小さい写真：ホームの最近の写真・一覧）
   - `lineWidthThin`（一覧の枠でだけ使っていた 1pt）は、使う場所が無くなるので消す。`lineWidthThick`（一覧の月の下の区切り）と `lineWidthStamp` は残す。`lineWidthThick` のコメントの「太さは仮」はそのまま
2. `Kouiunodeiindayo/Design/PhotoFrame.swift`（新規）— 写真のコマ枠の modifier
   - `enum PhotoFrame { case main, small }` と、`extension View { func photoFrame(_ frame: PhotoFrame) -> some View }`
   - 中身：`.clipped()`（四角く切り抜く）→ `.overlay { Rectangle().strokeBorder(Theme.line, lineWidth: 太さ) }`。太さは `Theme.photoFrameWidthMain / Small` を参照し、数値を直書きしない
   - 枠は押す判定に関わらないよう `.allowsHitTesting(false)`、読み上げからも外す（`accessibilityHidden(true)`）
   - コメントに「どこで main／small を使うか」「角丸は付けない（マンガのコマ）」を書く
3. `Kouiunodeiindayo/Features/Home/HomeView.swift`
   - 今日の一枚：`.clipShape(.rect(cornerRadius: 16))` を `.photoFrame(.main)` に替える（`.aspectRatio` の後）
   - 最近の写真：`.clipShape(.rect(cornerRadius: 8))` を `.photoFrame(.small)` に替える
4. `Kouiunodeiindayo/Features/List/RecordListView.swift` — `.overlay(Rectangle().stroke(Theme.line, lineWidth: Theme.lineWidthThin))` を `.photoFrame(.small)` に替える
5. `Kouiunodeiindayo/Features/Sort/SortCardView.swift` — `.clipShape(.rect(cornerRadius: 16))` を `.photoFrame(.main)` に替える
   - 「う、うまい」の `overlay` より**前**に付ける（ハンコが枠より手前に来る）
   - 後ろにのぞくカードも同じ View なので枠が付く。ラベル（`SortCardStackView` の overlay）は触らない
6. `Kouiunodeiindayo/Features/Detail/RecordDetailView.swift` — `photo` の写真（`Image` の `scaledToFit` の後）と、読み込み中の `Theme.surface`（`.aspectRatio` の後）の両方に `.photoFrame(.main)` を付ける
7. `Kouiunodeiindayo/Features/Home/RecordPhotoView.swift` — 先頭コメントの「大きさと角丸は呼ぶ側が決める」を「大きさと枠（`photoFrame`）は呼ぶ側が決める」に直す。ほかに「角丸」と書いたコメントが残っていないか `grep` で確かめる
8. 検証：`docs/rules/verification.md` どおり
   - ビルド・テスト
   - プレビューかシミュレータで、ホーム（今日の一枚あり）・一覧・仕分け（縦の写真、横長の写真、ドラッグ途中）・記録の詳細を見て、スクショを `.verification/62/` に残し、`notes.md` を書く
   - 見るところ：角が丸くない／主役 2pt・小さい写真 1.5pt に見える／「うまい」のハンコが枠に隠れていない／一覧・最近の写真のグリッドの間隔が変わっていない／文字サイズ最大でも崩れない

## リスク

- `strokeBorder` は写真の端を 1.5〜2pt 隠す。「うまい」のハンコは縁から 6〜12pt 離しているので重ならない見込み。スクショで確かめる
- #70（見出しの太さ・ロゴの大きさ）も `Theme.swift` を触る。先にマージされた側に、後の側が main を取り込んで合わせる

## 完成の確認方法

- 上の 8 のプレビュー・シミュレータのスクショ
- 実機での確認：要らない（見た目だけの変更。スワイプの手触りは変えていない）
