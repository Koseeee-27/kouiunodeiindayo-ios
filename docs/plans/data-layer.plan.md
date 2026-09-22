# 実装計画: データ層（Record・Genre・RecordStore・PhotoStorage・SampleData）

## 概要

`Data/` の5ファイルを作り、Xcode テンプレートの `Item` / `ContentView` を消す。対応する Issue：#10。対応する機能：機能2（撮って保存）、機能3（仕分け待ち）の土台。ほかの実装 Issue すべての前提。

データの形は `docs/data-model.md`、書き込みの入口の決まりは `docs/architecture.md` の「画面とデータの境界」が正。この計画はそれをファイルと関数に落としたもの。

## 前提・確認事項

- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- ビルド設定の既定（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、言語モードは Swift 5）により、何も付けなければ型はメインアクター上で動く。SwiftData をメインスレッドだけで使う決まりと合う。分離の不整合はエラーでなく警告になるので、警告が出たらその関数に `nonisolated` を付けて消す
- テスト用のターゲットは無い（足すには人が Xcode で操作する）。この Issue ではテストを足さず、仮の `RootView` に付けるデバッグ用のボタンで確認する
- 起動直後の画面は `App/RootView.swift` に仮のビューを置く。Issue は「空ビューでよい」だが、完成の条件（ファイルの作成・削除、実機で再起動しても残る）を確かめるため、`#if DEBUG` の中に「記録の件数」「サンプルを1件追加」「すべて消す」を置く。本物の RootView の Issue で丸ごと置き換える
- 決めたこと（迷ったら戻す先）
  - `Record` の enum 変換は `genreValue`（読み書きできる計算プロパティ）。`record.genre` は保存用の文字列のまま
  - `PhotoStorage` は保存先フォルダを `init` で受け取る `struct`。既定は `URL.applicationSupportDirectory.appending(path: "Photos")`（throw しない API なので `try!` が要らない）。SwiftUI の環境値（`\.photoStorage`）で画面に渡し、プレビューでは一時フォルダのものに差し替える
  - `PhotoStorage` は `Record` に依存しない（`photo(fileName:)`、`thumbnail(id:)`）。SwiftData を知らないファイル層にしておく
  - `RecordStore` は `struct`。`ModelContext` と `PhotoStorage` を `init` で受け取る（画面では `RecordStore(modelContext: modelContext, photoStorage: photoStorage)` と作って使う）
  - `Genre` に表示名は持たせない（文言は画面設計の関心事。画面の Issue で `Theme` か各画面に置く）
  - ログは `os.Logger`（subsystem はバンドル ID、category は型名）に統一する

## ステップ

1. `Kouiunodeiindayo/Data/Genre.swift` — `enum Genre: String, CaseIterable`。`unsorted` / `food` / `drink` / `dessert` / `noGenre = "none"`。`init(storedValue:)` で知らない文字列は `unsorted` に倒す／確認：ビルド
2. `Kouiunodeiindayo/Data/Record.swift` — `@Model final class Record`。`id`（`@Attribute(.unique)`）、`takenAt`、`createdAt`、`photoFileName`、`genre: String`、`isFavorite = false`。`genreValue: Genre` の計算プロパティ（get は `Genre(storedValue:)`、set は `rawValue` を書く）。`init(id:takenAt:createdAt:photoFileName:genre:isFavorite:)` は既定値つき／確認：ビルド
3. `Kouiunodeiindayo/Data/PhotoStorage.swift` — `struct PhotoStorage`
   - `init(directory: URL)`、`static let standard`（`Application Support/Photos/`）
   - `savePhotos(_ image: UIImage, id: UUID) throws -> String`：フォルダを `createDirectory(withIntermediateDirectories: true)` で作り、長辺 2000px・品質 0.8 の `<id>.jpg` と、長辺 400px の `<id>_thumb.jpg` を書き、写真のファイル名を返す。サムネイルは 2000px に縮小した画像からさらに縮小する（元画像を2回デコードしない）
   - 縮小と JPEG 化は `UIGraphicsImageRenderer` の `jpegData(withCompressionQuality:actions:)` で1回にまとめる。`UIGraphicsImageRendererFormat` は **`scale = 1`**（既定は画面の倍率なので、実機だと 6000px になってしまう）、`opaque = true`
   - `photo(fileName: String) -> UIImage?`、`thumbnail(id: UUID) -> UIImage?`
   - `deletePhotos(id: UUID, fileName: String) throws`：`fileExists` を見てから消す（無ければ成功扱い。サムネイルだけ欠けていてもエラーにしない）
   - `EnvironmentValues` に `@Entry var photoStorage = PhotoStorage.standard` を足す／確認：ビルド
4. `Kouiunodeiindayo/Data/RecordStore.swift` — `struct RecordStore`（`modelContext`、`photoStorage`）
   - `add(image: UIImage, takenAt: Date) throws -> Record`：先にファイルを保存し、成功したら `genre = unsorted` の記録を insert して save。insert / save に失敗したら、書いた2ファイルを消してから throw する（孤児ファイルを残さない）
   - `setGenre(_ genre: Genre, for record: Record)`、`toggleFavorite(_ record: Record)`、`setTakenAt(_ date: Date, for record: Record)`：値を書き換えるだけ（保存は SwiftData の自動保存）
   - `delete(_ record: Record) throws`：id と fileName を先に控え、記録を消して save し、そのあとファイルを消す（ファイルの削除に失敗しても記録の削除は戻さず、ログに残す）
   - `deleteAll() throws`：`FetchDescriptor<Record>()` で全件取り、1件ずつ `delete(_:)` を回す（`modelContext.delete(model:)` はバッチ削除で `@Query` の画面が更新されない既知の挙動があるため使わない。件数は数百〜数千件なので問題ない）／確認：ビルド
5. `Kouiunodeiindayo/Data/SampleData.swift` — `enum SampleData`
   - `static let photoStorage`：`temporaryDirectory/SamplePhotos/` の `PhotoStorage`
   - `static func makeContainer() -> ModelContainer`：`isStoredInMemoryOnly: true` の `ModelContainer`（プレビュー用なので `try!` 可）。空のまま返す
   - `static func makePreviewContainer() -> ModelContainer`：`makeContainer()` に、`RecordStore(modelContext: container.mainContext, photoStorage: photoStorage)` の `add` → `setGenre` / `toggleFavorite` でサンプルを 5 件入れて返す（書き込みは RecordStore を通す決まりを守る。サンプル写真のファイルもこれでできる）。色違いのサンプル画像は `UIGraphicsImageRenderer` で描く。仕分け待ち・食べ物・飲み物・デザート・なし・お気に入りありを一通り含め、`takenAt` は今日〜数日前
   - 画面の `#Preview` は `.modelContainer(SampleData.makePreviewContainer())` と `.environment(\.photoStorage, SampleData.photoStorage)` を付ける／確認：ステップ 7 のプレビューで件数とサムネイルが出る
6. `Kouiunodeiindayo/App/RootView.swift` — 仮のビュー。アプリ名の `Text` と、`#if DEBUG` の中に「記録の件数（`@Query`）」「サンプルを1件追加（描いた画像を `RecordStore.add`）」「すべて消す（`deleteAll`）」「最新1件のサムネイル」。`#Preview` はステップ 5 の container を使う／確認：プレビューでサンプル 5 件とサムネイルが出る
7. `Kouiunodeiindayo/App/KouiunodeiindayoApp.swift` — 自前の `ModelContainer` と `fatalError` を消し、`.modelContainer(for: Record.self)` にする。`RootView()` を出す／確認：ビルド
8. `Kouiunodeiindayo/Item.swift`・`Kouiunodeiindayo/ContentView.swift` を消す／確認：ビルド
9. シミュレータで起動する前に、**入っているアプリを削除する**（保存済みの `default.store` は `Item` のスキーマなので、そのままだと起動時に落ちることがある。`docs/data-model.md` の決まり）。実機も同じ
10. シミュレータで「サンプルを1件追加」→ `xcrun simctl get_app_container booted <bundle id> data` の `Library/Application Support/Photos/` に `<id>.jpg` と `<id>_thumb.jpg` ができる → 「すべて消す」→ 両方消える、を確かめる
11. `Kouiunodeiindayo.xcodeproj/xcshareddata/xcschemes/Kouiunodeiindayo.xcscheme`（Xcode が作った共有スキーム。Team ID 等は入っていない）を、この PR に含める。PR の説明に1行書く

## リスク

- `#Predicate` の中で `Genre.unsorted.rawValue` を直接書けない：この Issue の `@Query` は件数だけで条件を持たないが、後続の画面で使うときは先に `let` に取り出す（`docs/rules/swift.md`）
- `UIImage(contentsOfFile:)` で読んだ画像は `scale` が 1 になる。表示側で `.resizable()` を付ければ問題ない
- 縮小を毎回メインスレッドで行う：2000px の JPEG 化は 0.1 秒程度。撮影直後だけなので、この Issue では非同期化しない。もたつくなら後で `nonisolated` に切り出す
- `delete` でファイル削除だけ失敗すると孤児ファイルが残る：次の `savePhotos` には影響しないので、ログに残すだけにする

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）を通す
- `RootView` の `#Preview` で、サンプル 5 件の件数とサムネイルが出る
- ステップ 10 で、写真とサムネイルのファイルの作成・削除を確認する
- 実機（こうせいの iPhone）で「サンプルを1件追加」→ アプリを終了して開き直しても件数が減らず、サムネイルが出る。これは人が行う（Issue の完成の条件。verification.md の 4）
- PR を出す前に `docs/rules/self-review.md` のセルフレビュー。`Data/` の変更なので、別のツール（Codex 等）にも見せることを勧める
