# 実装計画: タグと提案をデータに足す（Tag・Record の項目・RecordStore の関数）

## 概要

`Data/Tag.swift` を作り、`Record` に `tags`・`suggestedGenre`・`suggestedTags`・`suggestedAt` を足し、`RecordStore` に「タグを変える」「提案を保存する」を足す。`SampleData` にタグ・提案つきの記録を足す。画面は変えない。対応する Issue：#81（親 #86）。対応する機能：`docs/requirements.md` の機能26（ジャンルとタグの提案）・機能27（タグを付ける）のデータの部分。#82・#83・#84・#85 はこれの後。

データの形は `docs/data-model.md`（「`Record`」「タグの値」「項目を足すときの決まり」）、書き込みの入口は `docs/architecture.md`（「書くとき」「提案（機能26）の流れ」）、Worker が返すキーは `docs/suggestion-api.md` が正。この計画はそれを型と関数に落としたもの。表の中身は繰り返さない。

## 前提・確認事項

- `project.pbxproj` は触らない。`Data/Tag.swift` は同期フォルダに置くだけでよい
- ビルド設定の既定（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）のまま。`Tag` は値だけの enum なので分離の問題は出ない
- 料理のタグの対応表は、`server/src/tags.ts`（#80 でマージ済み）の `DISH_TAGS` と `docs/data-model.md`「タグの値」が同じ内容なのを 9/26 に確認した。Swift の `Tag` もこれと同じにする（キー・Vision のラベル・大分類・系統）
- 知らないキーは「保存はそのまま・読むときに捨てる」。`Record.tags` は `[String]` のまま持ち、enum にする計算プロパティで `compactMap(Tag.init(rawValue:))` する（`Genre` のように既定値に倒さない。タグには「無い」が正しい既定なので）
- 提案の値の「知らないキーを捨てる」は、#82 の `SuggestionClient` が JSON を読むところで行う。`RecordStore` の「提案を保存する」は型（`Genre?`・`[Tag]`）で受け取るので、知らないキーはそもそも渡ってこない
- `ModelContext` の保存は、今の `setGenre`・`toggleFavorite` に合わせて自動保存に任せる（`save()` を呼ばない）。`add`・`delete` だけが明示的に `save()` している今の流儀を変えない
- 決めたこと（この計画の前提。変えるなら先にこの節を直す）
  - `Tag` は `enum Tag: String, CaseIterable`。case の並びは `docs/requirements.md`「タグの一覧」の順（料理 20 → 大分類 9 → 系統 5。計 34）。この並びを画面の並び順にも使う
  - 種類は `enum TagKind: CaseIterable { case dish, category, cuisine }`（`title`：料理／大分類／系統）。`Tag.kind` で引ける
  - `Tag.title`（日本語名）・`Tag.kind`・`Tag.visionLabels: [String]`（料理以外は空）・`Tag.category: Tag?`・`Tag.cuisine: Tag?`（料理以外は `nil`）を `switch` で持つ。`Genre.title` と同じ書き方
  - `Record` には `tagValues: [Tag]`・`suggestedGenreValue: Genre?`・`suggestedTagValues: [Tag]` の計算プロパティを足す（`genreValue` と同じ命名）。書き込みは `RecordStore` からだけ
  - 「言葉で探す」（#85）のための「料理のタグから大分類・系統に広げる」関数は、この Issue では作らない（使う画面がまだ無い。#85 で `category`・`cuisine` を使って足す）

### 決めたこと（2026-09-26 こうせい確認）

1. **テスト用のターゲット `KouiunodeiindayoTests` を足す。** 実装の前に、こうせいが Xcode で Unit Testing Bundle（Swift Testing）を足す（`project.pbxproj` が変わるので人の作業。ステップ 0）。テストのファイルは AI が書く。#82〜#85 でも使う
2. **「提案を保存する」が2回届いたら、2回目は何も書かない（先に届いたほうを使う）。** `suggestedAt` が入っていたら書かない。撮った直後と仕分けの画面を開いたときの問い合わせが重なっても、仕分けの画面でチップを外している最中に `suggestedTags` が差し替わって、外した状態が戻るのを防ぐため。`docs/architecture.md`「書くとき」の「提案を保存する」の行にも1文足す（ステップ 8）
3. **「タグを変える」は、重複を除き `Tag.allCases` の順（タグの一覧の順）に並べ直して保存する。** 仕分け・詳細で付け外しした順に関係なく、画面ごとに並びがぶれないようにするため
4. **提案のジャンルに `unsorted`・`noGenre` が渡されたら、`nil`（提案なし）として保存する。** `suggestedGenre` は `food`／`drink`／`dessert` か `nil`、という `docs/data-model.md` の決まりを `RecordStore` で守る
5. **`Tag.visionLabels` をアプリに持たせる。** 料理のタグを決めるのは Worker（`server/src/tags.ts`）で、今のところアプリでは使わないが、`docs/architecture.md` と Issue のとおり持たせる。2か所に同じ表がある状態になるので、ステップ 6 で突き合わせる

## ステップ

0. **（人の作業・実装の前）こうせいが Xcode でテスト用のターゲットを足す** — File → New → Target… → iOS → Unit Testing Bundle。Product Name は `KouiunodeiindayoTests`、Testing System は Swift Testing、Target to be Tested は `Kouiunodeiindayo`
   - 足したあと、`docs/setup.md` の付録 4〜6 と同じく、新しいターゲットの Build Settings に太字の Development Team・Bundle Identifier が残っていないかを見て、あれば消す。`git diff Kouiunodeiindayo.xcodeproj/project.pbxproj | grep DEVELOPMENT_TEAM` で何も出ないことを確かめる
   - 共有スキーム（`Kouiunodeiindayo.xcscheme`）の Test にこのターゲットが入っていることを確かめる（`xcodebuild test -scheme Kouiunodeiindayo` で走らせるため）
   - このコミットは人が行い、この PR に含める。AI は `project.pbxproj` に触らない
   - 確認：`docs/rules/verification.md` の 2 で、テンプレートの空のテストが通る
1. `Kouiunodeiindayo/Data/Tag.swift` — 新規
   - `enum TagKind: CaseIterable`：`dish`・`category`・`cuisine`。`title`（料理／大分類／系統）
   - `enum Tag: String, CaseIterable`：case 名は Swift の命名に合わせて lowerCamelCase、保存するキーは `docs/data-model.md` のまま（例：`case riceDish = "rice_dish"`、`case iceCream = "ice_cream"`、`case bubbleTea = "bubble_tea"`、`case bakedSweets = "baked_sweets"`）。並びはタグの一覧の順
   - `title: String`：日本語名（`docs/requirements.md`「タグの一覧」と同じ字。例：`vegetables` は「野菜・サラダ」）
   - `kind: TagKind`
   - `visionLabels: [String]`：`docs/data-model.md` の料理の表の「Vision のラベル」の列（決めたこと 5）。料理以外は `[]`
   - `category: Tag?`・`cuisine: Tag?`：料理の表の「大分類」「系統」の列。`—` と料理以外は `nil`
   - `static func tags(of kind: TagKind) -> [Tag]`：`allCases.filter { $0.kind == kind }`（#84 の一覧で種類ごとに並べるため）
   - ファイル先頭の doc コメントに「表は `docs/data-model.md`「タグの値」が正。`server/src/tags.ts` と同じ内容に保つ」と書く
   - 確認：ビルド
2. `Kouiunodeiindayo/Data/Record.swift` — 項目を足す
   - 保存する項目を宣言時の既定値つきで足す（**既定値は `init` ではなく宣言に書く**。SwiftData の自動の移行（保存済みデータへの項目の追加）は宣言の既定値を見るため）
     ```swift
     var tags: [String] = []
     var suggestedGenre: String? = nil
     var suggestedTags: [String] = []
     var suggestedAt: Date? = nil
     ```
   - 各項目に `docs/data-model.md` の意味を1行の doc コメントで（`suggestedAt` の「`nil` はまだ問い合わせていない」は必ず書く。#82 の問い合わせの条件になるため）
   - 計算プロパティ（読むだけ。書き込みは `RecordStore` から）
     - `tagValues: [Tag]`：`tags.compactMap(Tag.init(rawValue:))`。知らないキーは捨てる（表示しない・落とさない）
     - `suggestedGenreValue: Genre?`：`suggestedGenre.flatMap(Genre.init(rawValue:))`（知らない値は `nil`）
     - `suggestedTagValues: [Tag]`：`tags` と同じ
   - `init` の引数は増やさない（既存の呼び出しをそのまま通すため。値は `RecordStore` の関数で書く）
   - 確認：ビルド
3. `Kouiunodeiindayo/Data/RecordStore.swift` — 関数を2つ足す（`setGenre` と `toggleFavorite` の間あたり。`docs/architecture.md` の表の順）
   - `func setTags(_ tags: [Tag], for record: Record)`：「タグを変える」。仕分けで次に進むとき（#83）と、詳細での付け外し（#84）が呼ぶ。決めたこと 3 のとおり `Tag.allCases.filter(Set(tags).contains)` の順で `rawValue` を書く。`tags` だけを書き換え、`suggestedTags` には触らない
   - `func saveSuggestion(genre: Genre?, tags: [Tag], for id: UUID, at date: Date = .now)`：「提案を保存する」。#82 の `SuggestionService` がメインスレッドで呼ぶ
     1. `FetchDescriptor<Record>(predicate: #Predicate { $0.id == id })`、`fetchLimit = 1` で取り直す（`@Model` はスレッドをまたげないので `id` で受ける。`docs/architecture.md`）。`fetch` が throw したらログに残して何もしない（呼び出し側は裏の処理なので、失敗を返しても使い道が無い）
     2. 見つからない（仕分け中に記録が消された）→ 何も書かない。ログは `info`
     3. `genreValue != .unsorted`（届いたときにもう仕分け済み）→ 何も書かない
     4. `suggestedAt != nil`（もう問い合わせ済み）→ 何も書かない（決めたこと 2）
     5. `suggestedGenre`：決めたこと 4 のとおり、`food`・`drink`・`dessert` のときだけ `rawValue`、それ以外と `nil` は `nil`
     6. `suggestedTags`：重複を除いた `rawValue`（並びは決めたこと 3 と同じ `Tag.allCases` の順）
     7. `suggestedAt = date`。提案なし（`genre == nil`・`tags` が空）でも書く（問い合わせ済みにする。`docs/architecture.md`）
     8. `tags` には触らない
   - 引数の日時は、テストで固定の値を渡せるようにするため。呼び出し側は省略する
   - doc コメントに「何も書かない4つの場合」（取れない・見つからない・仕分け済み・問い合わせ済み）を書く
   - 確認：ビルド
4. `Kouiunodeiindayo/Data/SampleData.swift` — タグ・提案つきにする
   - `samples` の組に `tags: [Tag]` を足し、`setGenre` の後に `store.setTags` を呼ぶ（書き込みは RecordStore を通す）
     | 色 | ジャンル | タグ |
     |---|---|---|
     | orange（仕分け待ち） | — | なし |
     | red（食べ物・うまい） | 食べ物 | ラーメン・麺類・中華 |
     | teal（飲み物） | 飲み物 | コーヒー |
     | pink（デザート・うまい） | デザート | ケーキ |
     | gray（なし） | なし | なし |
   - 仕分け待ちの orange には、ループの後で `store.saveSuggestion(genre: .food, tags: [.ramen, .noodles, .chinese], for: record.id)` を呼ぶ（#83 の「提案あり」のプレビューになる。仕分け済みの記録は `saveSuggestion` が弾くので、`setGenre` より前に呼ぶ必要はない。仕分け待ちのまま呼ぶ）
   - 記録の数・ジャンル・うまい・日付は変えない（ホーム・仕分けの既存プレビューの見え方を変えないため）
   - doc コメントを「サンプルを 5 件入れたコンテナ。ジャンル・うまい・タグ・提案を一通り含む」に直す
   - `SortPreviewData`・`HomePreviewData` は触らない（`SortPreviewData.makeManyUnsortedContainer` で足される2件は `suggestedAt == nil` のままなので、そのまま「まだ問い合わせていない」の見本になる。提案が無い・届く前のプレビューは #83 で足す）
   - 確認：ビルド・ステップ 7
5. `KouiunodeiindayoTests/`（ステップ 0 でターゲットができてから）— Swift Testing でテストを書く。`@MainActor` の `struct`。`SampleData.makeContainer()`（メモリ上）と、一時フォルダの `PhotoStorage`（テストごとに `URL.temporaryDirectory.appending(path: UUID().uuidString)`）で `RecordStore` を作り、記録は `store.add(image: SampleData.makeImage(color:), takenAt:)` で作る
   - `import Testing` の `Tag`（テストに付ける目印の型）とアプリの `Tag` がぶつかるので、テストでは `Kouiunodeiindayo.Tag` と書くか、ファイルの先頭で `typealias AppTag = Kouiunodeiindayo.Tag` にする
   - `TagTests.swift`
     - キーが 34 個・重複なし。種類ごとの数が 20・9・5
     - 料理のタグは `category`・`cuisine` がどちらも料理でない（`kind` が合っている）、料理以外は `visionLabels` が空・`category`・`cuisine` が `nil`
     - 代表の対応：`ramen` → `noodles`・`chinese`、`curry` → `riceDish`・`nil`、`alcohol` の `visionLabels` が 7 個
   - `RecordTests.swift`
     - 新しく作った記録は `tags` が空・`suggestedGenre`・`suggestedAt` が `nil`・`suggestedTags` が空
     - `tags` に知らないキー（例：`"unknown_tag"`）を混ぜても、`tagValues` はそれを除いたもの（落ちない）。`suggestedGenre` が `"unsorted"` や知らない値でも `suggestedGenreValue` が落ちない
   - `RecordStoreTagsTests.swift`
     - `setTags`：書いたキーが `tags` に入る／重複が除かれ、`Tag.allCases` の順に並ぶ／空を渡すと空になる／`suggestedTags` は変わらない
     - `saveSuggestion`：仕分け待ちには3項目が入る・`tags` は空のまま／**仕分け済み（`setGenre(.food)` 後）には何も書かない**／`delete` 後の `id` で呼んでも落ちず、ほかの記録も変わらない／提案なし（`nil`・`[]`）でも `suggestedAt` が入る／2回目は無視される（1回目の値のまま）／`.noGenre`・`.unsorted` を渡すと `suggestedGenre` が `nil`
   - 確認：`docs/rules/verification.md` の 2
6. 対応表の突き合わせ（1回だけ。コードには残さない）— `Tag` の料理 20 個のキー・Vision のラベル・大分類・系統が、`server/src/tags.ts` の `DISH_TAGS` と同じかを目で見るか、使い捨てのスクリプトで比べる。違っていたら、どちらが正しいかをこうせいに確認してから直す（`AGENTS.md`「仕様と実装が食い違ったら」）
7. 保存済みのデータからの更新の確認（シミュレータ。Issue の完成の条件の1つ目）
   1. `main` をビルドしてシミュレータに入れ、起動して記録を数件作る（撮る代わりにアルバムから選ぶ。仕分け待ち・仕分け済み・うまいを混ぜる）
   2. **アプリを消さずに**このブランチをビルドして上書きで入れ、起動する
   3. 落ちない・ホームと一覧の記録が前と同じ・仕分け待ちの枚数が同じ、を見る。スクショを `.verification/81/` に残す
8. `docs/architecture.md` — 「書くとき」の表の「提案を保存する」の行の最後に、「もう問い合わせ済み（`suggestedAt` が入っている）なら、何も書かない（先に届いたほうを使う）」の1文を足す（決めたこと 2。実装と同じ PR で直す）。`docs/data-model.md` は変えない見込み（項目と表は #77 で書き済み）

## プレビューでの見え方

- この Issue では画面を変えないので、どのプレビューも見た目は今と同じになるはず（タグ・提案を表示する画面がまだ無い）
- 確認するのは「今のプレビューが全部開ける・落ちない・件数とジャンルが変わっていない」こと。特に `SampleData.makePreviewContainer()` を使う `HomeView`・`SortView`・`RecordDetailView`・一覧のプレビューと、`SortPreviewData`・`HomePreviewData` の各プレビュー
- データが入ったかは、ステップ 5 のテストで見る

## #50（デモ用のデータ）との相性

- 足す項目はどれも宣言の既定値つき・optional なので、#50 のデータを先に入れても後に入れても、SwiftData の自動の移行で読める見込み。ステップ 7 で同じ状況（古い形のデータがあるまま更新）を確かめる
- #50 のデータ（取り込んだ写真）は `suggestedAt == nil` になる。#82 が入ると、仕分け待ちのものだけ仕分けの画面を開いたときに問い合わせが走る。仕分け済みのものはタグが空のまま（デモで詳細のタグを見せたいなら、#50 の入れ方で `setTags` を呼ぶか、詳細で手で付ける）。これは #50 の Issue にコメントで書いておく
- デモ機に #50 のデータを入れるのは、この PR をマージした後にする（念のため。落ちたときに入れ直しになるのを避ける）

## リスク

- **既定値を `init` の中だけに書くと、保存済みデータで起動時に落ちる**：SwiftData の自動の移行は宣言の既定値を使う。ステップ 2 のとおり宣言に書き、ステップ 7 で上書きインストールを必ず試す。開発中に落ちたら `docs/data-model.md` の決まりどおりアプリを消して入れ直す（デモ機ではやらない）
- **`[String]` を `#Predicate` の中で使うと実行時に失敗する報告がある**：この Issue では `tags`・`suggestedTags` を条件に使わない。`saveSuggestion` の条件は `id` だけにして、仕分け済みかどうかは取ったあとに Swift 側で見る
- **`#Predicate` の中で引数の `id` を直接使う**：`UUID` の比較は書ける。`Genre.unsorted.rawValue` のような式は書けないので、ジャンルの判定を `#Predicate` に入れない（`docs/rules/swift.md`）
- **Swift Testing の `Tag` との名前のぶつかり**：テストのファイルで `Tag` と書くと曖昧になりコンパイルエラーになる。ステップ 5 のとおり修飾する。アプリ側（`import Testing` しない）では問題ない
- **`Tag` と `server/src/tags.ts` の表がずれる**：2か所に同じ表がある。ステップ 6 で突き合わせ、`Tag.swift` と `tags.ts` の先頭のコメントで、互いと `docs/data-model.md` を指す（`tags.ts` はもう data-model を指している）
- **`SampleData` の変更で、ほかの人のプレビューの前提が変わる**：数・ジャンル・うまい・日付を変えないので、見た目は変わらない。`SortView` のプレビューで仕分け待ちの1件に提案が入るが、#83 まで表示されない
- **`saveSuggestion` の自動保存のタイミング**：`save()` を呼ばないので、提案を書いた直後にアプリが落ちると消える。消えても `suggestedAt` が `nil` に戻るだけで、次に仕分けの画面を開いたとき問い合わせ直すので害は無い

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）。警告を増やさない
- `docs/rules/verification.md` の 2（テスト）。ステップ 5 のテストが全部通る
- 既存のプレビュー（ホーム・仕分け・記録の詳細・一覧）が開けて、見た目が今と同じ
- ステップ 6 の突き合わせで、`Tag` と `server/src/tags.ts` の料理の表が同じ
- ステップ 7 の上書きインストールで落ちない（Issue の完成の条件の1つ目）
- Issue の完成の条件との対応：1つ目 → ステップ 7／2つ目 → ステップ 5 の `RecordStoreTagsTests`／3つ目 → ステップ 5 の `RecordTests`
- 実機での確認：要らない（Issue のとおり。画面・カメラ・手触りを触らない）
- PR を出す前に `docs/rules/self-review.md` のセルフレビュー。`Data/` の変更で #82〜#85 が全部乗るので、別のツールにも見せることを勧める

## 実装で変えたこと（2026-09-26）

- テストは計画の3ファイルに加えて `KouiunodeiindayoTests/TestSupport.swift`（メモリ上のコンテナ・一時フォルダの `PhotoStorage`・`RecordStore` をまとめて作る `TestStore`）を足した。テストのターゲットは既定のアクター分離がアプリと違う（MainActor でない）ので、テストの `struct` には `@MainActor` を付けた。`SampleData.makeImage(color:)` の `UIColor` を使うため `import UIKit` が要る（`MemberImportVisibility` でエラーになる）
- `SampleData` の仕分け待ちへの `saveSuggestion` は、ループの後ではなくループの中（`setTags` の後、`genre == .unsorted` のとき）で呼んだ。記録を取り直す手間が無いため。結果は計画と同じ
- `Tag.visionLabels`・`category`・`cuisine` の `switch` は、料理以外をまとめて `default:` にした
- `docs/architecture.md` は、ステップ 8 の1文に加えて、「タグを変える」の行に「重複を除き、タグの一覧の順に並べ直して書く」（決めたこと 3）を足し、フォルダ構成に `KouiunodeiindayoTests/` を足した
- ステップ 7 は、アルバムから選ぶ操作の代わりに、main の版が作った `default.store` の `ZRECORD` に sqlite3 で古い形の記録を4件入れて行った（アプリの入っていないシミュレータ iPhone 17 で。普段使いのシミュレータのデータを消さないため）。開いたときの画面は `simctl spawn … defaults write <bundle id> launchScreen home` でホームにした。結果は落ちず、4 列が足されて4件とも残った
