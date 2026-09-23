# 実装計画: 設定（プライバシーポリシー・お問い合わせ・バージョン）

## 概要

App Store の審査に出すため、ホーム右上から開く最小の設定画面を作り、プライバシーポリシーとお問い合わせのページを開けるようにし、バージョンを出す。対応する Issue：#44。対応する機能：機能22。

要素は `docs/screen-design.md` の「設定」が正。設定画面に載せる機能のうち、今回作るのは機能22 だけ。ほかの項目（機能17・19・20・25）は作るときに足す。

## 前提・確認事項

- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- `Design/Theme.swift`（#23）はまだ無い。見た目は標準の部品（`List`・`Link`・`LabeledContent`）のままにする
- 実機での確認は要らない（Issue の記載どおり）
- ホームの `HomeView.swift` 以外の画面は触らない。`RecordListView.swift`・`RecordDetailView.swift` はわかなさん担当
- 決めたこと（2026-09-23 にこうせいと確認。迷ったら戻す先）
  - **入口はホーム右上のアイコン**（確定版ワイヤーの仮置きのまま決定）。`docs/screen-design.md` の「ホーム」「画面のつながり」と `docs/architecture.md` はこの PR で更新済み
  - **開き方は `sheet`。中に `NavigationStack` を置き、題名「設定」と「閉じる」ボタンを出す。** 下に引いても閉じられる。下タブは出さない（sheet なので自然に隠れる）
  - **「開いたときの画面」の切り替え（機能25）は今回入れない。** 別の Issue にする
  - **お問い合わせは LP の `/support` を開く。** `mailto:` はシミュレータにメールアプリが無いと何も起きず、確認できないため使わない
  - **外部ページは `Link` で Safari に渡す**（アプリ内ブラウザは使わない。Issue のメモどおり）
  - **URL はコードの1か所（`AppLinks`）にまとめる。** LP の公開先のドメインはまだ決まっていない（LP リポの `docs/pages.md` が正）。決まるまでは `https://example.com` を土台にした仮の値にし、決まったら土台の1行を差し替えるだけで済むようにする
- 実装中に決めたこと（計画に書いていなかった細部。2026-09-23、実装時）
  - `#URL` マクロは使わず、`URL?` のまま持つ（iOS 26 の SDK での有無を確かめる手間に見合わないため）
  - 「閉じる」の置き場所は `.confirmationAction`（iOS 26 以降は右上に丸いボタンで出る）
  - 外部リンクの行は、読み上げで「Safari で開く」とヒントを添え、右の矢印は読み上げから隠す
  - 歯車のアイコンは `.font(.title2)` にした（44pt の押せる枠に対して見た目も大きめにするため。文字サイズ設定には追従する。#23 で見直す）

## ステップ

1. `Kouiunodeiindayo/Features/Settings/AppLinks.swift` — 外部ページの URL をまとめる `enum AppLinks`
   - `static let privacyPolicy: URL`（`/privacy`）と `static let support: URL`（`/support`）を持つ
   - 土台の URL は1か所にし、「LP の公開先が決まったら差し替える。正は kouiunodeiindayo-lp の docs/pages.md」とコメントを書く
   - `docs/rules/swift.md` により強制アンラップ（`!`）は使えない。型は `URL?`（`URL(string:)` の結果のまま）にし、ビュー側は `if let` で行を出す。文字列の URL を optional でない `URL` にする Foundation の `#URL` マクロは、iOS 26 の SDK にあるかを Apple のドキュメントで確かめられた場合だけ使ってよい
   - 確認方法：ビルドが通る
2. `Kouiunodeiindayo/Features/Settings/SettingsView.swift` — 設定画面
   - `NavigationStack` の中に `List`。セクションは1つ（見出しは「このアプリについて」）
     - 「プライバシーポリシー」→ `Link(destination: AppLinks.privacyPolicy)`
     - 「お問い合わせ」→ `Link(destination: AppLinks.support)`
     - 「バージョン」→ `LabeledContent("バージョン", value: ...)`。値は `Bundle.main` の `CFBundleShortVersionString` と `CFBundleVersion` から `1.0 (1)` の形で作る。取れなかったときは `-` にする（強制アンラップしない）
     - 外部に出る行だと分かるよう、`Link` の行の右に `Image(systemName: "arrow.up.right")` を付ける（標準の Settings アプリに近い見せ方）
   - `.navigationTitle("設定")`、`.navigationBarTitleDisplayMode(.inline)`
   - `.toolbar` に「閉じる」ボタン（`@Environment(\.dismiss)` を呼ぶ）。置き場所は右上（`.topBarTrailing`、または `.confirmationAction`）
   - `#Preview` を付ける（データを使わないので `modelContainer` は要らない）
   - 確認方法：プレビューで3行と「閉じる」が見える
3. `Kouiunodeiindayo/Features/Home/HomeView.swift` — 右上に設定のアイコンを置き、`sheet` で `SettingsView` を開く
   - ホームは `NavigationStack` を持たず `ScrollView` だけなので、`.toolbar` は使えない。`ScrollView` の中の `VStack` の先頭に、右寄せの行（`HStack { Spacer(); Button }`）を置く
     - 仕分け待ちの帯より上に置く。帯が無いときも位置が変わらないようにする
   - アイコンは `Image(systemName: "gearshape")`。押せる大きさを 44pt 四方以上にする（`.frame(minWidth: 44, minHeight: 44)` と `.contentShape(.rect)`）
   - `.accessibilityLabel("設定")`
   - `@State private var isSettingsShown = false` を足し、`.sheet(isPresented: $isSettingsShown) { SettingsView() }`
   - 既存の `.sheet(item: $selectedRecord)` と同じビューに2つの `sheet` を付けても動くが、付ける場所は `ScrollView` の同じ階層でよい
   - 確認方法：プレビュー（仕分け待ちあり／なし）で右上にアイコンが出る
4. 検証（`docs/rules/verification.md`）
   - ビルド
   - シミュレータで：ホーム → 右上のアイコン → 設定が下から出る → 「プライバシーポリシー」「お問い合わせ」を押すと Safari が開く（仮の URL なので中身は example.com でよい）→ アプリに戻って「閉じる」、下に引いても閉じる → バージョンが `1.0 (1)` と出る
   - 文字サイズ最大（アクセシビリティの文字サイズ）で、ホーム右上のアイコンと設定の各行が崩れない
   - スクショを `.verification/44/` に残し、`notes.md` に操作と見るところを書く

## リスク

- 右上のアイコンは自前の行なので、#23（Theme）が入ったときに見た目を合わせ直す必要がある。今は標準の見た目で置くだけにする
- URL は仮の値なので、LP の公開前はリンクが example.com を開く。PR の説明に書き、LP の公開後に `AppLinks` の土台の1行を差し替える（差し替えは別の小さな PR でよい）
- ホームに `sheet` が2つになる。同時には開かないので問題ないが、#13 で詳細の開き方を `fullScreenCover` に変えても設定のほうは影響しない

## 完成の確認方法

- 上のステップ4。実機での確認は要らない
- Issue #44 の完成の条件（リンクが開ける・バージョンが出る・URL が1か所）を満たしている
