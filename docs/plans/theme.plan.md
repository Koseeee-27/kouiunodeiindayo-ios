# 実装計画: Theme（配色の反映）

## 概要
`Design/Theme.swift` に色と線の太さを定義し、各画面が色を直書きせずに `Theme` を参照するようにする。配色は Notion「デザイン要件書」の確定版（マンガのコマ）。対応する Issue：#23。対応する機能番号：なし（デザイン要件書の反映）

## 前提・確認事項
- 配色（デザイン要件書の確定版）

  | 名前（`Theme`） | 役割 | 色 |
  |---|---|---|
  | `main` | メイン（ボタン・強調） | #26221F（墨） |
  | `accent` | アクセント（「うまい」のハンコ・仕分けのスタンプ） | #CC3327（赤） |
  | `background` | 背景（画面の地） | #F9F6EE |
  | `surface` | 背景（段差。カード・写真の読み込み中など一段上の面） | #FFFFFF |
  | `textPrimary` | 文字（主） | #26221F |
  | `textSecondary` | 文字（副） | #6E6862 |
  | `line` | 線・区切り | #26221F |

- 線の太さ `lineWidth` は 1pt（仮）。Figma の 4px は強いので細くする、という決定に沿う
- アプリは明るい表示に固定する（ダーク用の色が未定のため）
- アプリ全体の強調色（tint）は墨。赤はハンコ・スタンプだけ
- この Issue でやらないこと：背景のドット、タイトルロゴ（#59）、ハンコの形（#58）、余白・角丸の基準値（未定）
- フォント（游ゴシック）は別途（iOS で使えるかの確認が要るため、この計画の後で足す）→ 実装中に決まったので、この Issue で入れた（末尾の「実装しながら変えた点」）

## ステップ
1. `Kouiunodeiindayo/Design/Theme.swift` — `enum Theme` を作り、上の表の 7 色を `static let` の `Color` で置く（HEX から `Color(red:green:blue:)` で作る。HEX を受け取る小さな初期化を private に置いてよい）。`static let lineWidth: CGFloat = 1` も置く / ビルドが通る
2. `Kouiunodeiindayo/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` — AccentColor に墨（#26221F、sRGB）を入れる。`.tint`・`.accentColor`・`.borderedProminent` がまとめて墨になる / シミュレータで下タブの選択中・目立つボタンが墨
3. `Config/Base.xcconfig` — `INFOPLIST_KEY_UIUserInterfaceStyle = Light` を足す（アプリを明るい表示に固定） / シミュレータをダークモードにしても明るいまま
4. 各画面の直書きの色を `Theme` に置き換える
   - 画面の地を `Theme.background` にする：`HomeView`、`RecordListView`、`SortView`、`RecordDetailView`、`SettingsView`（`Form` は `.scrollContentBackground(.hidden)` を付けてから地を差し替える）、`CameraAccessGuideView`
   - `RecordListView`：枠線 `.stroke(.primary, lineWidth: 1)` → `Theme.line`・`Theme.lineWidth`。見出しの下線 `.fill(.primary)` → `Theme.line`
   - 文字の `.secondary`（`SettingsView`、`CameraAccessGuideView`、`RootTabBar` の選ばれていない側）→ `Theme.textSecondary`
   - `SortStampView` の `.red`、`RecordDetailView` の `.red` → `Theme.accent`
   - 写真の読み込み中の `Color.secondary.opacity(0.2)`（`RecordPhotoView`、`SortCardView`、`RecordDetailView`）→ `Theme.surface`
   - 変えないもの：写真の上に重ねる `.regularMaterial`（写真の上で読めることを優先）、`CameraFlowView` の `Color.black`（カメラの背面）、`SampleData` の色（プレビュー用の写真の代わり）
5. `SortGenreLabelView` の `glassEffect(.regular.tint(.accentColor))` はステップ 2 で墨になる。墨のガラスの上で白い文字が読めるかを見る / 読みにくければ報告する（勝手に作り替えない）
6. 検証（`docs/rules/verification.md`）— ビルド → テスト → シミュレータでホーム・仕分け・一覧・詳細・設定のスクショを撮って `.verification/23/` に保存する。ダークモードに切り替えたスクショも 1 枚撮る

## リスク
- 墨の tint で、下タブの選択中と選ばれていない側（#6E6862）の差が小さく見えることがある → スクショで見て、弱ければ報告する
- #58（ハンコ）・#59（ロゴ）と同じファイルを触る → 先にマージしたほうに合わせて、あとのほうが直す
- `Form` の地の差し替えは、`scrollContentBackground(.hidden)` を忘れると効かない

## 完成の確認方法
- シミュレータのスクショで、ホーム・仕分け・一覧・詳細・設定の地が #F9F6EE、強調が墨、スタンプが赤になっている
- Liquid Glass の部品（下タブ・仕分けのラベル）が、配色と競合していない（見て確認）
- 画面のコードに `.red`・`.primary`・`.secondary` の色の直書きが残っていない（`grep` で確認。`.secondary` の文字の階層指定として意図して残すものは理由を書く）
- 実機での確認は要らない

## 実装しながら変えた点
- `RootView` のページャー（`TabView`）にも地を敷いた。ページャーはステータスバーと下タブの周りまで地を広げないため
- フォントもこの Issue で入れた（9/25 決定：游ゴシック。iOS に入っていないので、見た目の近いヒラギノ角ゴで代わりにする）。`Theme.font(_:bold:)` を置き、画面の `.font(.headline)` などをすべて置き換えた。指定のない本文・ボタンのために、アプリの入口で `.font(Theme.font(.body))` を当てている
- 直書きを残さないため、`Theme` に `onMain`（墨の地の上の白）を足し、線の太さを `lineWidthThin`（1pt、写真の枠）と `lineWidthThick`（2pt、見出しの下の区切り）に分けた。`Theme.main` は AccentColor を参照し、墨の値を Asset の1か所にまとめた
- 「記録を消す」は赤ではなく墨にした（赤はハンコ・スタンプだけ）
- コードの「#23 で見直す」のコメントは、行き先の Issue（#57・#58）か「仮」に書き換えた
- 写真の枠・吹き出し・ドットの地・見出しの字など、雰囲気を変える形の変更は、この Issue では行わない。ワイヤーで候補を比べてから、別の Issue にする
