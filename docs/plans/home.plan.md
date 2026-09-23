# 実装計画: ホーム（今日の一枚・最近の写真・仕分け待ちの入口・撮るボタン）

## 概要

`Features/Home/HomeView.swift` の仮ビューを本物に置き換える。今日の一枚を大きく出し、その下に最近の写真を4枚、上に仕分け待ちの入口（枚数つき）を置く。今日まだ撮っていない日は「今日はまだ撮っていません」と撮るボタン。対応する Issue：#14。対応する機能：機能23（ホーム）、機能14（仕分け待ちへの入口）。

要素と状態は `docs/screen-design.md` の「ホーム」、取り出し方は `docs/data-model.md` の「よく使う取り出し方」が正。この計画はそれをファイルと関数に落としたもの。見た目は標準の部品でシンプルに作り、色・フォント・余白は #23（Theme）で当てる（`docs/architecture.md` の「並行して作るための約束」）。

## 前提・確認事項

- #10（データ層）・#11（RootView と下タブ）・#15（カメラ）・#16（仕分け）はマージ済み。`HomeView` は `Text("ホーム")` だけの仮ビュー。`RecordListView`（#12）と `RecordDetailView`（#13）はわかなさん担当で、まだ仮ビュー。**この Issue では `RecordListView.swift`・`RecordDetailView.swift` を触らない**
- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- `Design/Theme.swift`（#23）はまだ無い。色・フォント・余白は標準のまま（`.headline` など）。値を直書きするのは余白の数字だけにし、#23 で `Theme` に寄せる
- 実機での確認は要らない（Issue の記載どおり。カメラ・スワイプ・効果音・写真の保存は触らない）
- 決めたこと（Issue #14 のメモ「ここで決めて `docs/data-model.md` に書く」の分。2026-09-23 にこうせいと確認。迷ったら戻す先）
  - **今日の一枚は、今日撮った記録のうち `takenAt` が一番新しい1枚。** 「いま食べたもの」が出るのが自然で、並びの先頭を取るだけで済む。お気に入り優先にすると、「う、うまい」を付けた日に古い写真が固定されてしまうので採らない
  - **最近の写真は4枚。今日の一枚を除いて、`takenAt` の新しい順。** 今日の一枚と同じ写真が2回出ないようにする。今日撮っていない日は、最新の4枚がそのまま出る。確定版ワイヤーフレーム（9/22。Notion の参考リンク）の仮置き「4枚」をそのまま採る
  - **仕分け待ちの入口は、画面の上部の帯**（確定版ワイヤーの仮置きの形）。押すと `fullScreenCover` で `SortView()` を出す。`SortView` は ✕ と最後の1枚を仕分けたときに `dismiss()` するので、カバーはそれで閉じる。仕分け待ちが0枚のときは帯ごと出さない
  - **今日の一枚・最近の写真のタップは `sheet(item:)` で仮の `RecordDetailView()` を出す。** 記録の詳細の開き方（sheet か fullScreenCover か。閉じるボタンの位置）は #13 で決める。仮ビューには閉じるボタンが無いので、下に引いて閉じられる `sheet` にしておく。#13 は `HomeView` のこの1行を書き換えてよい（「あとからできた側が接続する」。`RecordDetailView(record:)` のように記録を渡す形になる見込みなので、どの記録を押したかは `selectedRecord` に持っておく）
  - **撮るボタンは、`RootView` からクロージャで受け取る**（`HomeView(onTakePhoto:)`）。`RootView` 側は `HomeView { select(.camera) }` の1行で、既存の `select(_:)` を通す（`withAnimation` とカバーの出し方を1か所に保つ）。環境値にしないのは、呼ぶ場所がこの1つだけだから
  - **「今日」の判定は `body` の中で `Calendar.current.isDateInToday(_:)` を使う。** `@Query` の `#Predicate` に日付の計算は書けない（`docs/rules/swift.md`）。仕分け済みを新しい順に取る `@Query` を1本持ち、先頭が今日なら今日の一枚、残りの先頭4件が最近の写真、と `body` で切り分ける。日付をまたいでも再描画されるまで変わらない点は `swift.md` の注意どおりで、許容する
    - 実装して分かったこと（Codex のレビューで指摘）：先頭だけを見ると、#13 で日付を未来に直した記録があるとき、今日の記録があっても「今日はまだ撮っていません」になる。今日の一枚は `records.first(where:)` で今日の記録を探し、最近の写真はその `id` だけを除く形にした（並びは新しい順のままなので、「今日の中で一番新しい1枚」は変わらない）
  - **写真を読むビューは `RecordPhotoView`（`Features/Home/`）として切り出す。** `SortCardView` と同じ「地の上に重ねてから切り抜く」「`.task(id: record.id)` で1回だけ読む」の型。写真本体かサムネイルかを引数で切り替える。#12（一覧）のグリッドでも使えるので、architecture.md に書いておく（#12 が使うかは #12 の計画で決める）
  - **記録が0件のときは、最近の写真の見出しごと出さない。** 画面設計の状態に「記録ゼロ」は無く（一覧の #20 の関心事）、「今日はまだ撮っていません」＋撮るボタンだけで迷わない

## ステップ

1. `Kouiunodeiindayo/Features/Home/RecordPhotoView.swift` — 新規。記録1件の写真を `PhotoStorage` から読んで出すビュー
   - `enum Kind { case photo, thumbnail }`（`RecordPhotoView` の中に入れ子。引数に使うので private にしない）
   - `let record: Record`、`let kind: Kind`、`@Environment(\.photoStorage)`、`@State private var image: UIImage?`
   - `body`：`Color.secondary.opacity(0.2)` の `.overlay` に `Image(uiImage:)` を `.resizable().scaledToFill()` で重ね、`.clipped()`。大きさ・角丸は呼ぶ側が決める（`.aspectRatio` と `.clipShape` は付けない）。`.task(id: record.id)` で `kind` に応じて `photoStorage.photo(fileName:)` か `photoStorage.thumbnail(id:)` を読む
   - `accessibilityLabel` は付けない（押せる場所は呼ぶ側の `Button` に付ける）。画像には `.accessibilityHidden(true)`
   - ファイル先頭のコメントに「`SortCardView` と同じ型。一覧（#12）のグリッドでも使える」と書く
   - `#Preview`：`SampleData.makePreviewContainer()` の記録を1件取り、`.photo` と `.thumbnail` を並べる（コンテナから取るのは `SortPreviewData.makeFavoriteContainer()` と同じ `FetchDescriptor` の書き方）／確認：ビルド、プレビューで単色の画像が2つ出る
2. `Kouiunodeiindayo/Features/Home/HomePreviewData.swift` — 新規。ホームのプレビュー用のサンプルデータ（`SortPreviewData` と同じ型）
   - `makeNoUnsortedContainer()`：`SampleData.makePreviewContainer()` の `unsorted` の記録に `store.setGenre(.food, for:)` を当てる（仕分け待ち0枚。今日の記録が2件になるので「今日が複数あるとき一番新しい1枚が出る」の確認にもなる）
   - `makeNoTodayContainer()`：`SampleData.makeContainer()` に、`daysAgo` 1〜4 の記録を4件（ジャンルは `food`／`drink`／`dessert`／`noGenre`、1件は `toggleFavorite`）。仕分け待ち無し・今日の記録無し
   - `makeManyContainer()`：`SampleData.makePreviewContainer()` に、`daysAgo` 4〜9 の `food` の記録を6件足す（仕分け済みが計 10 件。最近の写真が4枚で止まる確認）
   - 画像は `SampleData.makeImage(color:)`。色は `UIColor.systemGreen` / `.systemPurple` / `.systemIndigo` / `.systemBrown` などを回す。プレビュー用なので `try!` 可／確認：ビルド
3. `Kouiunodeiindayo/Features/Home/HomeView.swift` — 仮ビューを本物に書き換える
   - `private static let unsorted = Genre.unsorted.rawValue`
   - `let onTakePhoto: () -> Void`
   - `@Query(filter: #Predicate<Record> { $0.genre != unsorted }, sort: \Record.takenAt, order: .reverse) private var records: [Record]`（仕分け済み。新しい順）
   - `@Query(filter: #Predicate<Record> { $0.genre == unsorted }) private var unsortedRecords: [Record]`（枚数だけ使う。`SortView` と同じ書き方）
   - `@State private var selectedRecord: Record?`（詳細を開く記録）、`@State private var isSortShown = false`
   - 計算プロパティ：`todayRecord: Record?` は `records.first` が `Calendar.current.isDateInToday($0.takenAt)` のときだけ。`recentRecords: [Record]` は `records.dropFirst(todayRecord == nil ? 0 : 1).prefix(4)` を `Array` に
   - `body`：`ScrollView` の中に `VStack(alignment: .leading, spacing: 24)`。上から、仕分け待ちが1枚以上なら `sortEntry`、`todaySection`、`recentRecords` が空でなければ `recentSection`。`.padding()`。`ScrollView` にするのは、文字サイズ最大や小さい画面で下が切れないようにするため（`RootView` の `safeAreaInset` で下タブの分は空く）
   - `.sheet(item: $selectedRecord) { _ in RecordDetailView() }`。コメントに「#13 で記録を渡す。開き方（sheet か fullScreenCover か）も #13 で決めてよい」
   - `.fullScreenCover(isPresented: $isSortShown) { SortView() }`。コメントに「`SortView` は ✕ と最後の1枚で `dismiss()` するので、カバーはそれで閉じる」
   - `sortEntry`：`Button { isSortShown = true }` のラベルは `HStack` に `Image(systemName: "tray.full")`、`Text("仕分け待ち \(unsortedRecords.count) 枚")`、`Spacer()`、`Image(systemName: "chevron.right")`。`.padding()`、`.background(.regularMaterial, in: .rect(cornerRadius: 12))`、`.buttonStyle(.plain)`。`accessibilityLabel("仕分け待ち \(n) 枚。仕分けを始める")`
   - `todaySection`：`Text("今日の一枚").font(.headline)` の下に、
     - `todayRecord` があれば `Button { selectedRecord = record }`。ラベルは `RecordPhotoView(record: record, kind: .photo)` に `.aspectRatio(1, contentMode: .fit)`（正方形。大きさは仮で、#23 で見直す）、`.clipShape(.rect(cornerRadius: 16))`。`.buttonStyle(.plain)`、`accessibilityLabel("今日の一枚。記録の詳細を開く")`
     - 無ければ `VStack(spacing: 16)` に `Text("今日はまだ撮っていません")` と `Button("撮る") { onTakePhoto() }`（`.buttonStyle(.borderedProminent)`、`accessibilityLabel("カメラを開いて撮る")`）。`.frame(maxWidth: .infinity)`、上下に余白（`.padding(.vertical, 48)`）を取って、写真の代わりの場所だと分かるようにする
   - `recentSection`：`Text("最近の写真").font(.headline)` の下に `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8)`。各セルは `Button { selectedRecord = record }`、ラベルは `RecordPhotoView(record: record, kind: .thumbnail)` に `.aspectRatio(1, contentMode: .fit)`、`.clipShape(.rect(cornerRadius: 8))`。`.buttonStyle(.plain)`、`accessibilityLabel("\(record.takenAt.formatted(date: .abbreviated, time: .omitted)) の写真。記録の詳細を開く")`。`ForEach(recentRecords, id: \.id)`
   - ファイル先頭のコメント：役割、正の場所（画面設計「ホーム」・データ設計「よく使う取り出し方」）、「今日の一枚は今日の一番新しい1枚、最近の写真は今日の一枚を除く4枚」
   - `#Preview` を5つ：「今日の一枚あり・仕分け待ちあり」（`SampleData.makePreviewContainer()`）、「今日の一枚あり・仕分け待ちなし」（`HomePreviewData.makeNoUnsortedContainer()`）、「今日まだ撮っていない」（`makeNoTodayContainer()`）、「記録ゼロ」（`SampleData.makeContainer()`）、「記録が多い」（`makeManyContainer()`）。すべて `HomeView(onTakePhoto: {})` に `.modelContainer(...)` と `.environment(\.photoStorage, SampleData.photoStorage)`／確認：5つのプレビューが出て、状態ごとに帯・今日の一枚・最近の写真の有無が変わる
4. `Kouiunodeiindayo/App/RootView.swift` — `HomeView()` を `HomeView { select(.camera) }` に差し替える（触るのはこの1行。#8 の「並行して作るときの約束」）。`select(_:)` の doc コメントは「カメラのカバーが出ている間はバーが隠れるので〜」のままでよい（撮るボタンもカバーが閉じているときにしか押せない）／確認：ビルド。プレビュー「ホームから開く」でホームの本物が出る
5. `docs/data-model.md` — 「よく使う取り出し方」の2行を埋める
   - ホームの今日の一枚：条件「`genre` が `unsorted` 以外で、`takenAt` が今日。複数あるときは `takenAt` が一番新しい1枚」、並び「—」
   - ホームの最近の写真：条件「`genre` が `unsorted` 以外で、今日の一枚を除く。4件」、並び「`takenAt` の新しい順」
   - 「画面設計で決まり次第ここに書く」の文言は消す／確認：文書だけ
6. `docs/architecture.md` — 「フォルダ構成」の `Features/Home/` に `HomeView.swift`（今日の一枚・最近の写真・仕分け待ちの入口・撮るボタン）、`RecordPhotoView.swift`（記録1件の写真かサムネイルを `PhotoStorage` から読むビュー。一覧のグリッドでも使える）、`HomePreviewData.swift`（ホームのプレビュー用のサンプルデータ）を足す。「ホーム・一覧・カメラの行き来は下タブ」の箇条書きに「ホーム・一覧の仕分け待ちの入口は、それぞれの画面が `fullScreenCover` で `SortView` を出す。記録の詳細の開き方は #13 で決める（ホームは仮に `sheet`）」を添える／確認：文書だけ
7. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/14/` に残す（git には入れない。PR には写真と文章で貼る）。シミュレータの操作は #16 と同じく Xcode の MCP（`DeviceInteractionSynthesize`）でよい。確認の前にアプリを削除して、記録0件から始める
   - `preview-HomeView-今日あり-仕分け待ちあり.png`、`preview-HomeView-今日あり-仕分け待ちなし.png`、`preview-HomeView-今日なし.png`、`preview-HomeView-記録ゼロ.png`、`preview-HomeView-記録が多い.png`
   - `01-起動してキャンセル-記録ゼロのホーム.png`：起動 → 写真ライブラリでキャンセル → ホーム。「今日はまだ撮っていません」と撮るボタン。帯も最近の写真も無い
   - `02-撮るボタン-写真ライブラリ.png`：撮るボタンを押す → カメラのカバー（シミュレータなので写真ライブラリ）が上がる。下タブの選択は「カメラ」
   - `03-写真を選んで食べ物-今日の一枚.png`：写真を選ぶ → 仕分けで「食べ物」を押す → ホーム。今日の一枚にその写真。帯も最近の写真も無い
   - `04-もう1枚選んで抜ける-仕分け待ち1枚の帯.png`：下タブ「カメラ」→ 写真を選ぶ → ✕ で抜ける → ホーム。上に「仕分け待ち 1 枚」の帯。今日の一枚は 03 のまま（仕分け待ちは出ない）
   - `05-帯を押す-仕分け.png`：帯を押す → 仕分けが全画面で出て「あと 1 枚」
   - `06-デザートで仕分け-今日の一枚が入れ替わり-最近に1枚.png`：「デザート」を押す → ホームに戻る。帯が消え、今日の一枚が今仕分けた写真に替わり、最近の写真に 03 の写真が1枚
   - `07-今日の一枚をタップ-詳細の仮.png`：今日の一枚を押す → 仮の「記録の詳細」がシートで出る → 下に引いて閉じる
   - `08-最近の写真をタップ-詳細の仮.png`：最近の写真を押す → 同じく仮の詳細が出る
   - `09-ホームから一覧へ横スワイプ.png`：ホームで左へスワイプ → 一覧（仮）に移る。帯・写真の上からのスワイプでもページが動く
   - `10-文字サイズ最大-ホーム.png`：文字サイズを最大（accessibility-extra-extra-extra-large）にする。帯の文言・「今日の一枚」・「最近の写真」・撮るボタンが切れず、下タブに隠れない（スクロールで見られる）
   - `notes.md` に写真ごとの「操作」と「見るところ」を表で書く。#16 の `notes.md` と同じ形（日時・環境・操作の合成方法も冒頭に）
8. `docs/rules/self-review.md` のセルフレビューを回してから PR（`Closes #14`）。PR の題名は `feat: ホーム画面に今日の一枚・最近の写真・仕分け待ちの入口を作る` のような形

## リスク

- **`sheet(item:)` と `Record` の `Identifiable`**：`Record` は `@Model` で、`PersistentModel` の `Identifiable` と自前の `id: UUID` を両方持つ。`ForEach(records, id: \.id)` は通っているが、`sheet(item: $selectedRecord)` で型が曖昧だとコンパイルが通らないことがある。通らなければ `@State private var isDetailShown = false` と `selectedRecord` の2つに分け、`.sheet(isPresented:)` にする
- **`ScrollView` と横のページャーの干渉**：`RootView` の `TabView(.page)` の中に縦の `ScrollView` を置く。軸が違うので両立するはずだが、帯や写真（`Button`）の上から始めた横スワイプでページが動かなければ、`Button` を `.onTapGesture` に替えるのではなく、`.simultaneousGesture` を試す前に、まずスクショ 09 で実際に動かないかを確かめる
- **今日の一枚の写真本体の読み込み**：2000px の JPEG をメインスレッドで読む（`SortCardView` と同じ）。ホームを開くたびに 0.1 秒程度。もたつくなら別 Issue にする（`@Query` の更新のたびに `.task(id:)` は走らないので、読み直しは記録が替わったときだけ）
- **`@Query` が仕分け済みを全件持つ**：ホームで使うのは先頭5件だけだが、`@Query` は全件を配列に持つ。数百件なら問題ない。気になるなら `FetchDescriptor` の `fetchLimit` を使う形に替えるが、この Issue ではやらない
- **日付をまたいだとき**：0時をまたいでホームを開いたままだと、再描画されるまで「今日の一枚」が昨日の写真のまま。`swift.md` の注意どおり許容する。カメラから戻れば再描画される
- **仮の `RecordDetailView` に閉じるボタンが無い**：`sheet` なら下に引いて閉じられる。`fullScreenCover` にすると閉じられなくなるので、#13 が閉じるボタンを付けるまでは `sheet` のまま
- **文字サイズ最大で「仕分け待ち n 枚」が折り返す**：`Spacer()` と `chevron` があるので2行になるだけで切れない。`.lineLimit(1)` は付けない（`minimumScaleFactor` で縮めるより折り返すほうが読める）
- **プレビューの「今日」**：`SampleData` の `daysAgo: 0` は `Date.now` なので、プレビューを開いた時点で今日になる。`makeNoTodayContainer()` は `daysAgo` 1 以上だけにする

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- `HomeView` のプレビュー5つで、状態ごとに帯・今日の一枚・最近の写真の有無が変わる（Issue の完成の条件「プレビューで3状態が出せる」）
- シミュレータで、記録0件のホームに「今日はまだ撮っていません」と撮るボタンが出て、撮るボタンでカメラのカバーが上がる
- シミュレータで、仕分けた写真が今日の一枚に出て、仕分け待ちの写真は今日の一枚にも最近の写真にも出ない。仕分け待ちが1枚以上のときだけ帯が出て、押すと仕分けが開く
- シミュレータで、今日の一枚・最近の写真を押すと仮の詳細が開く
- シミュレータで、ホームから横スワイプで一覧に移れる
- 文字サイズ最大でも文言が切れない
- 実機での確認：**要らない**（Issue の記載どおり）
