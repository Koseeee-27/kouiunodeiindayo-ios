# 実装計画: データ層（Record・Genre・RecordStore・PhotoStorage・SampleData）

## 概要

`Data/` の5ファイルを作り、Xcode テンプレートの `Item` / `ContentView` を消す。対応する Issue：#10。対応する機能：機能2（撮って保存）、機能3（仕分け待ち）の土台。ほかの実装 Issue すべての前提。

データの形は `docs/data-model.md`、書き込みの入口の決まりは `docs/architecture.md` の「画面とデータの境界」が正。この計画はそれをファイルと関数に落としたもの。

## 前提・確認事項

- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- ビルド設定の既定（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）により、何も付けなければ型はメインアクター上で動く。SwiftData をメインスレッドだけで使う決まりと合う
- テスト用のターゲットは無い（足すには人が Xcode で操作する）。この Issue では、ファイルの作成・削除の確認は一時的なプレビューで行い、テストは足さない
- 決めたこと（迷ったら戻す先）
  - `Record` の enum 変換は `genreValue`（読み書きできる計算プロパティ）。`record.genre` は保存用の文字列のまま
  - `PhotoStorage` は保存先フォルダを `init` で受け取る `struct`。既定は `Application Support/Photos/`。SwiftUI の環境値（`\.photoStorage`）で画面に渡し、プレビューでは一時フォルダのものに差し替える
  - `RecordStore` は `struct`。`ModelContext` と `PhotoStorage` を `init` で受け取る（画面では `RecordStore(modelContext: modelContext, photoStorage: photoStorage)` と作って使う）
  - 起動直後の画面は `App/RootView.swift` に仮のビューを置く（本物は RootView の Issue で作り直す）

## ステップ

1. `Kouiunodeiindayo/Data/Genre.swift` — `enum Genre: String, CaseIterable`。`unsorted` / `food` / `drink` / `dessert` / `noGenre = "none"`。`init(storedValue:)` で知らない文字列は `unsorted` に倒す。表示名（食べ物／飲み物／デザート／なし）を `label` に持つ／確認：ビルド
2. `Kouiunodeiindayo/Data/Record.swift` — `@Model final class Record`。`id`（`@Attribute(.unique)`）、`takenAt`、`createdAt`、`photoFileName`、`genre: String`、`isFavorite = false`。`genreValue: Genre` の計算プロパティ（get は `Genre(storedValue:)`、set は `rawValue` を書く）。`init(id:takenAt:createdAt:photoFileName:genre:isFavorite:)` は既定値つき／確認：ビルド
3. `Kouiunodeiindayo/Data/PhotoStorage.swift` — `struct PhotoStorage`
   - `init(directory: URL)`、`static let `default``（`Application Support/Photos/`）
   - `savePhotos(_ image: UIImage, id: UUID) throws -> String`：フォルダを作り、長辺 2000px・品質 0.8 の `<id>.jpg` と、長辺 400px の `<id>_thumb.jpg` を書き、写真のファイル名を返す
   - `photo(for record: Record) -> UIImage?`、`thumbnail(for record: Record) -> UIImage?`
   - `deletePhotos(for record: Record) throws`、`deleteAll() throws`（フォルダごと消す）
   - 縮小は `UIGraphicsImageRenderer`（向きを保ったまま縮小できる）を使う private extension
   - `EnvironmentValues` に `@Entry var photoStorage = PhotoStorage.default` を足す／確認：ビルド
4. `Kouiunodeiindayo/Data/RecordStore.swift` — `struct RecordStore`（`modelContext`、`photoStorage`）
   - `add(image: UIImage, takenAt: Date) throws -> Record`：先にファイルを保存し、成功したら `genre = unsorted` の記録を insert して save
   - `setGenre(_ genre: Genre, for record: Record)`、`toggleFavorite(_ record: Record)`、`setTakenAt(_ date: Date, for record: Record)`：値を書き換えるだけ（保存は SwiftData の自動保存）
   - `delete(_ record: Record) throws`：記録を消して save し、そのあとファイルを消す（ファイルの削除に失敗しても記録の削除は戻さず、ログに残す）
   - `deleteAll() throws`：`modelContext.delete(model: Record.self)` → save → `photoStorage.deleteAll()`／確認：ビルド
5. `Kouiunodeiindayo/Data/SampleData.swift` — `enum SampleData`
   - `static let modelContainer`：`isStoredInMemoryOnly: true` の `ModelContainer`（プレビュー用なので `try!` 可）
   - `static let photoStorage`：`temporaryDirectory/SamplePhotos/` の `PhotoStorage`
   - `static func makeRecords(in context:)`：色違いのサンプル画像（`UIGraphicsImageRenderer` で描く）を 5 件ほど。仕分け待ち・食べ物・飲み物・デザート・なし・お気に入りありを一通り含める。`takenAt` は今日〜数日前
   - `static let previewContainer`：上のレコードを入れ終わった container（画面の `#Preview` はこれと `.environment(\.photoStorage, SampleData.photoStorage)` を付ける）／確認：`#Preview` で サムネイルが並ぶ
6. `Kouiunodeiindayo/App/KouiunodeiindayoApp.swift` — 自前の `ModelContainer` を消し、`.modelContainer(for: Record.self)` にする。`RootView()` を出す／確認：ビルド
7. `Kouiunodeiindayo/App/RootView.swift` — 仮のビュー（アプリ名の `Text` のみ）と `#Preview`／確認：シミュレータで起動
8. `Kouiunodeiindayo/Item.swift`・`Kouiunodeiindayo/ContentView.swift` を消す／確認：ビルド
9. 動作確認（コミットしない一時コード）：`RecordStore.add` → `Application Support/Photos/` に2ファイル → `delete` → 両方消える、をプレビューかシミュレータで確かめる

## リスク

- `#Predicate` の中で `Genre.unsorted.rawValue` を直接書けない：この Issue では `@Query` を書かないが、`SampleData` や後続の画面で使うときは先に `let` に取り出す（`docs/rules/swift.md`）
- `Application Support` は最初は存在しない：`savePhotos` で毎回 `createDirectory(withIntermediateDirectories: true)` する
- `UIImage(contentsOfFile:)` で読んだ画像は、`scale` が 1 になる。表示側で `.resizable()` を付ければ問題ない
- 縮小を毎回メインスレッドで行う：2000px の JPEG 化は 0.1 秒程度。撮影直後だけなので、この Issue では非同期化しない。もたつくなら後で `nonisolated` に切り出す
- `deleteAll` の途中でファイル削除だけ失敗すると、孤児ファイルが残る：次の `savePhotos` には影響しないので、ログに残すだけにする

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）を通す
- `RootView` と `SampleData` の `#Preview` が表示される
- ステップ 9 で、写真とサムネイルのファイルの作成・削除を確認する
- 実機で写真を保存し、アプリを終了して開き直しても残っていること：この Issue にはカメラも保存ボタンも無いので、実機での確認は「撮って保存」の画面の Issue で行う。PR にその旨を書く
