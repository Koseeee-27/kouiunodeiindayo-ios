# 実装計画: 「うまい」を付けたときに、ハンコを押す動きと振動を付ける（段 A）

## 概要

仕分けの「う、うまい」と、記録の詳細の「うまい」を押して**付けたとき**に、ハンコを押す動き（アニメーション）と振動を付ける。外すときは付けない。効果音（段 B）は音源が決まってから（この計画には入れない）。対応する Issue：#22（親 #9）。対応する機能：機能24。要素と操作は `docs/screen-design.md` の「仕分け」「記録の詳細」（PR #115 で書いた）が正。

main（#103・#84 入り）から `feat/22-umai-feedback` を切って作る。**目安：1.5 時間**（部品 45 分・2 画面に付ける 15 分・プレビューと検証 30 分）。

## 決めたこと（2026-09-27、こうせいと確認。ideas-0927 の 1。#22 の本文）

- 1-1：ハンコを押す動き。押すと絵が 1.4 倍くらいから少し傾いて「ドン」と縮んで止まる（0.25 秒・弾みあり）。同時に振動（中）。周りに一瞬だけ薄い輪が広がる。1 秒以内に落ち着く
- 1-2：外すときは演出なし（動き・振動なし）で薄くなるだけ
- 1-3：マナーモードでは効果音を鳴らさない（段 B の話。振動は鳴る）
- 1-4：仕分けと記録の詳細で同じ演出（絵の大きさだけ違う）
- （計画のときの要判断 1。2026-09-27 こうせい確認）一瞬広がる輪は、ハンコの絵と同じ角丸の四角を、ハンコの赤（`Theme.accent`）の細い線で、絵の外側に 1.3 倍まで広げながら消す（0.35 秒）
- （計画のときの要判断 2）「視差効果を減らす」（Reduce Motion）がオンのときは、大きさ・傾き・輪の動きは出さず、濃くなるだけ。振動は出す
- 見た目（大きさ・傾き・時間・輪）は、この値で実装してから、こうせいが実機で見て直す（数値は `Theme` に集める）
- 段 A（振動＋アニメーション）を先に入れる。9/24 MTG の「やりすぎない」は、9/27 にこうせいが変えた

## 前提・確認事項

- 仕分け：`Features/Sort/SortCardView.swift` の `favoriteButton`（絵 `umaiStamp`／`umaiStampOutline`、幅 220pt、`Theme.sortFavoriteTilt` で傾け、付いていないとき薄さ 0.5）。押せるかは `isFavoriteEnabled`（#103 で、ボタンの中でも `guard isFavoriteEnabled`）。`SortCardStackView` が `isFront && !isInteractionLocked` を渡し、渡し口でも `guard !isInteractionLocked`（おまかせ中・飛んでいる間は押せない）
- 詳細：`Features/Detail/RecordDetailView.swift` の `RecordDetailPageView.favoriteButton`（絵 `umaiBadge`、幅 `Theme.detailFavoriteBadgeWidth`、傾けない、付いていないとき薄さ 0.4）。押すと `store.toggleFavorite(record)`
- 振動は、仕分けのカードが飛ぶときと同じ `sensoryFeedback` の書き方（`SortCardStackView`）
- **#103 のおまかせと両立**：演出は「`record.isFavorite` が false → true に変わったとき」だけ出す。おまかせは `isFavorite` を変えない・おまかせ中は押せない（上の `guard`）ので、おまかせで演出が出ることは無い。演出の部品は押せるかどうかを見ない（押せるかは今の `guard` のまま）

## 作り方

### 演出の部品（`Design/StampPressEffect.swift`、新規）

```swift
extension View {
    /// 「うまい」のハンコを押したときの演出（機能24）。`isOn` が false → true に変わった瞬間だけ、
    /// 大きく少し傾いた状態からドンと縮んで止まり、同じ形の輪が外に広がって消え、振動する。true → false では何もしない。
    /// 最初に表示したとき（すでに付いている記録を開いたとき）は出さない。
    func stampPress(isOn: Bool) -> some View
}
```

- 中身は `ViewModifier`：`@State private var pressID = 0`（押した回数）と、`.onChange(of: isOn) { old, new in if !old && new { pressID += 1 } }`。`onChange` は最初の表示では呼ばれないので、開いたときには出ない
- 動き：`keyframeAnimator(initialValue:trigger: pressID)` で、大きさ 1.4 → 0.95 → 1.0、傾き +8° → 0°（0.25 秒・弾みあり）。数値は `Theme` に置く（`stampPressScale`・`stampPressTilt`・`stampPressDuration`）
- 輪：同じ `pressID` で、絵の形の角丸の四角（決めたこと）を `overlay` に置き、大きさ 1.0 → 1.3・薄さ 0.6 → 0 を 0.35 秒で。押せる範囲には入れない（`allowsHitTesting(false)`）・読み上げから隠す
- 振動：`.sensoryFeedback(.impact(weight: .medium), trigger: pressID)`
- Reduce Motion（決めたこと）：`@Environment(\.accessibilityReduceMotion)` が true なら、動きと輪を出さず、振動だけ
- `keyframeAnimator` は iOS 17〜（`#available` 不要）

### 2 画面に付ける

- `SortCardView.favoriteButton`：絵（`Image(...)`）の `.opacity(...)` のあとに `.stampPress(isOn: record.isFavorite)`。傾き（`rotationEffect(Theme.sortFavoriteTilt)`）はそのまま（演出の傾きは、その上に重なる）
  - カードが次の写真に替わっても出ないこと：`SortCardStackView` はカードを記録の `id` で並べるので、`SortCardView` は記録ごとに別のビュー。後ろのカードが先頭に来ても `record.isFavorite` は変わらないので出ない
- `RecordDetailPageView.favoriteButton`：絵の `.frame(...)` のあとに `.stampPress(isOn: record.isFavorite)`。左右にめくっても、ページごとに別のビューなので出ない
- ボタンの押せる範囲・読み上げ（`accessibilityLabel`・`.isSelected`）は変えない

## ステップ

1. `Kouiunodeiindayo/Design/Theme.swift` — 演出の数値（大きさ・傾き・時間・輪の広がり・輪の色は `Theme.accent`）
2. `Kouiunodeiindayo/Design/StampPressEffect.swift`（新規）— 上の部品。プレビュー：押すたびに付け外しするボタン（キャンバスの Live で動きを見る）と、静止画で「押した直後の最初のコマ」（プレビュー専用の引数で `pressID` を 1 にしたうえで、キーフレームの最初の値を出す）
3. `Kouiunodeiindayo/Features/Sort/SortCardView.swift`・`Kouiunodeiindayo/Features/Detail/RecordDetailView.swift` — 付ける
4. 確認：`docs/rules/verification.md` の 1・2（テストは今のまま通ること。演出にはテストを書かない。付け外しの書き込みは今の `toggleFavorite` のまま）。プレビュー：`StampPressEffect` の 2 つ・`SortView` の「1枚」「うまいが付いている」・`RecordDetailView` の既存のもの。スクショを `.verification/22/` に
5. シミュレータ：仕分けで「う、うまい」を付ける・外す／詳細で「うまい」を付ける・外す／おまかせ中に押しても何も起きない（#103 の確認と同じ）／設定の「視差効果を減らす」をオンにして付ける。動きは画面の録画（`xcrun simctl io booted recordVideo`）で撮り、`.verification/22/` に置く（PR には静止画のスクショを貼る）
6. `docs/requirements.md`・`docs/screen-design.md`：PR #115 で書いた（直さない）。#115 がまだマージされていなければ、この PR には入れない
7. コミット `feat: 「うまい」を付けたときにハンコを押す動きと振動を付ける (#22)`

## 実機での確認（こうせいが行う）

| 操作 | 見るところ |
|---|---|
| 仕分けで「う、うまい」を付ける | ハンコがドンと押される動き・輪・振動（中）。1 秒以内に落ち着く。写真は次に進まない |
| もう一度押して外す | 動き・振動なしで薄くなる |
| 記録の詳細で「うまい」を付ける・外す | 仕分けと同じ動き（絵の大きさだけ違う）。外すときは何もなし |
| おまかせ中に「う、うまい」を押す | 何も起きない（#103） |
| うまいが付いている記録の詳細を開く・左右にめくる | 開いたとき・めくったときに演出が出ない |
| 設定 → アクセシビリティ → 動作 → 視差効果を減らす をオン | 動きは出ず、振動だけ |
| 続けて何度も押す | 動きが途中で重なっても、崩れずに止まる |

## リスク

- **傾いた絵に、さらに演出の傾きが重なる**（仕分けは `sortFavoriteTilt` 18°）。演出の傾きは小さく（+8°）、止まったときは元の傾きに戻る。見た目は実機で見る
- **輪がカードの外にはみ出す**（仕分けの「う、うまい」はカードの右上で、上の縁から少しはみ出している）。輪はカードの枠で切れない（`overlay` の外）ので、上のラベルに一瞬かかることがある。気になれば広がりを 1.2 倍に
- **振動が二重になる**：仕分けのカードが飛ぶときの振動とは、きっかけが別（`commitCount` と `pressID`）なので重ならない
- 効果音（段 B）を足すときは、`SoundPlayer` を同じ `pressID` で鳴らす（`.ambient` でマナーモードに従う）。この計画では足さない

## 完成の確認方法

- `docs/rules/verification.md` の 1・2
- プレビュー・シミュレータの録画（上のステップ 4・5）
- 実機（こうせい）：上の表。Issue の完成の条件の「実機で動き・振動を確認」はここで見る
