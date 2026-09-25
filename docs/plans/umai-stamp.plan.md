# 実装計画: 「うまい」を横長の長方形にして写真の右上に置く

## 概要

仕分けの「う、うまい」を、かえでさんのハンコの絵（横長の長方形）に替えて写真の右上に傾けて置く。ホーム・一覧の「うまい」は、同じ横長の長方形をアプリ側で作り、写真の右上に置く。デザイン要件書の「『うまい』のハンコ」（9/24 MTG で決定、9/25 に四角から横長に変更）の反映。対応する Issue：#58。対応する機能：`docs/requirements.md` の機能5（見た目）。

## 前提・確認事項

- `project.pbxproj` は触らない。画像は `Assets.xcassets` の中にフォルダと `Contents.json` を置くだけで入る
- 押したときの効果音・アニメーションはこの Issue ではやらない（#22）
- 決めたこと（2026-09-25 にこうせいと確認済み）
  - **仕分けはハンコの絵を使う。** 押す前は「色なし」（線だけ）、押した後は「色付き」の絵に切り替える。濃さ（opacity）で薄くするのはやめる
  - **ホーム（今日の一枚・最近の写真）と一覧は、絵を使わずアプリ側で作る。** 横長の長方形の枠と「うまい」の文字。線と文字は赤（`Theme.accent`）。写真の右上に、仕分けと同じく左下がりに傾ける
  - **記録の詳細は今のまま**（表記「うまい」・置き場所・見た目とも変えない）
  - 素材の原本はワークスペースの `assets/stamp/`（`umai-stamp.svg` が色付き、`umai-stamp-outline.svg` が色なし）。ここからコピーする
- 絵の字は「うまい」で、仕様の表記「う、うまい」（`docs/requirements.md` 機能5・`docs/screen-design.md`）と食い違う。読み上げのラベルは見た目に合わせて「うまい」にする。ドキュメントの表記の扱いはこうせいが決めて直す（AI は直さない）

## ステップ

1. `Kouiunodeiindayo/Resources/Assets.xcassets/` — 画像を 2 つ足す
   - `UmaiStamp.imageset/umai-stamp.svg`（色付き）と `UmaiStampOutline.imageset/umai-stamp-outline.svg`（色なし）。コピー元は `../assets/stamp/`
   - 各 `Contents.json` は下の形。`preserves-vector-representation` で、大きくしても線がぼやけないようにする

     ```json
     {
       "images" : [ { "filename" : "umai-stamp.svg", "idiom" : "universal" } ],
       "info" : { "author" : "xcode", "version" : 1 },
       "properties" : { "preserves-vector-representation" : true }
     }
     ```
   - 確認：ビルドが通り、`Image(.umaiStamp)` / `Image(.umaiStampOutline)`（Xcode が作る画像の名前）で参照できる。参照できなければ `Image("UmaiStamp")` にする
2. `Kouiunodeiindayo/Design/Theme.swift` — 「うまい」の傾き `static let favoriteTilt = Angle.degrees(-6)` を足す（左下がり。SwiftUI は左回りがマイナス）。仕分けとホーム・一覧で同じ値を使う
3. `Kouiunodeiindayo/Features/Sort/SortCardView.swift` — `favoriteButton` の中身を絵に替える
   - `Image(record.isFavorite ? .umaiStamp : .umaiStampOutline)` を `.resizable().scaledToFit().frame(width: 120)` くらいで出し、`.rotationEffect(Theme.favoriteTilt)`。2 つの絵は縦横比が少し違う（色付き 754:289・色なし 791:315）ので、幅をそろえて `scaledToFit` にし、切り替わっても位置がずれないことを見る
   - `.opacity(record.isFavorite ? 1.0 : 0.4)` と `.dynamicTypeSize(...DynamicTypeSize.large)`（絵は文字サイズで変わらないので要らない）を消す。`.allowsHitTesting(isFavoriteEnabled)` と `.padding(12)`、`.accessibilityAddTraits(.isSelected)` は残す
   - 押せる範囲は絵の四角全体にする（`.contentShape(.rect)`。色なしの絵は中が透けるので、無いと線の上しか押せない）
   - `.accessibilityLabel("うまい")` に替える
   - 先頭のコメント・`isFavoriteEnabled` のコメントの「う、うまい」を合わせて直す。`SortCardStackView.swift` の `stampTopInset`・`SortGenreLabelView.swift` の上限のコメントに出てくる「う、うまい」も、中身が合わなくなる所だけ直す
4. `Kouiunodeiindayo/Features/Home/RecordPhotoView.swift` — `favoriteLabel` を横長の長方形にして右上へ
   - `.overlay(alignment: .bottomLeading)` を `.topTrailing` に
   - 見た目：`Text("うまい")`、文字と枠線は `Theme.accent`、地は `Theme.background`（仕分けの絵の中と同じクリーム）、角の無い長方形の枠（`.rect` に `strokeBorder`。太さは写真本体 2pt・サムネイル 1pt くらいから）、`.rotationEffect(Theme.favoriteTilt)`。横長に見えるよう、左右の余白を上下より大きく取る
   - 大きさは今の `isLarge` の分け方（写真本体は `.headline` 太字・サムネイルは `.caption`）を土台に、プレビューで見て決める
   - 文字サイズ最大でも「…」にならないよう、今の `.lineLimit(1)` と `.minimumScaleFactor` は残す
   - 傾けた角が写真の外（切り抜きの外）にはみ出して隣と重ならないか、角を持つ親（一覧・ホームのグリッド）で切れないかを見る。はみ出すなら右上の余白（`.padding`）を広げる
   - `.regularMaterial` の地はやめる。「見た目は仮（四角にして右上に置くのは #58）」のコメントを消し、何をしているかの説明に替える
   - 呼ぶ側（`HomeView`・`RecordListView`）は `showsFavoriteLabel: true` のままなので直さない
5. 検証：`docs/rules/verification.md` どおり
   - プレビュー：`SortView` の「うまいが付いている」「幅 375pt」、`SortCardView`、`RecordPhotoView`、ホーム・一覧の各プレビュー
   - 見るところ：仕分けの絵が右上で左下がり／押す前は色なし・押した後は色付き／幅 375pt で上のラベルと重ならない／ホーム・一覧の「うまい」が右上で横長・傾いている／文字サイズ最大（AX5）ではみ出しも「…」も無い

## 実装して分かったこと（2026-09-25）

- **仕分けの絵の幅は 120pt ではなく 100pt にした。** 120pt だと幅 375pt のプレビューで上のラベル（食べ物）と重なり、iPhone 18 Pro（幅 402pt）でもほぼくっついた。100pt で、375pt でも数 pt 空く
- **ホーム・一覧のサムネイルの「うまい」も太字にした**（計画は `.caption` のまま）。細字だと赤い線の枠の中で字が弱く見えたため。枠線は写真本体 `Theme.lineWidthThick`（2pt）・サムネイル `Theme.lineWidthThin`（1pt）、写真の縁からの余白は写真本体 12pt・サムネイル 6pt。AX5 でも「…」やはみ出しは無い
- **「う、うまい」のコメントは、計画にあったファイルに加えて `SortView.swift` と `SortGenreLabelView.swift` のコメントも「うまい」に揃えた。** `SortView` の「幅 375pt」のプレビューの説明は、絵が文字サイズで変わらないことに合わせて直した
- `docs/architecture.md` のフォルダ構成の `SortCardView.swift ← 写真1枚のカードと「う、うまい」` は直していない（表記の扱いはこうせいが決めるため）
- シミュレータで押して色なし ↔ 色付きが切り替わるのは見ていない。プレビューで両方の状態（`SortCardView` は色なし・`SortView`「うまいが付いている」は色付き）を見た

## リスク

- 仕分けの絵は文字サイズで大きさが変わらないので、上のラベル（文字サイズで大きくなる、上限 Large）との重なりは幅 375pt のプレビューだけ見ればよい。重なるなら絵の幅を縮める
- サムネイル（一覧は幅 110pt ほど・ホームの最近の写真は 80pt ほど）では字が小さい。読めない大きさなら、サムネイルだけ少し大きくするか `minimumScaleFactor` を見直す
- 傾けると四角の角が元の枠からはみ出す（-6° で数 pt）。右上の余白が小さいと写真の外や親の切り抜きで欠ける

## 完成の確認方法

- 上の 5 のプレビューで確認する。シミュレータで、仕分けの「うまい」を押して色なし ↔ 色付きが切り替わることも見る
- 実機での確認は要らない（Issue のとおり）
- ドキュメント（こうせい）：ワークスペースの確定版ワイヤーの「うまい」を横長の長方形に直して公開し直す。`docs/screen-design.md` の「半透明の『う、うまい』」（押す前の見た目・表記）が、色なしの絵・表記「うまい」と食い違うので直す
