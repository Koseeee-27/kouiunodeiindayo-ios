# Swift / SwiftUI / SwiftData の決まり

このプロダクト固有の書き方の決まり。前提（対応 OS、Xcode のバージョン、外部ライブラリ無し）は `AGENTS.md`、理由は `docs/adr/`。
Xcode 27・iOS 27 は 2026-09-14 に出たばかりで、AI の知識や Web の記事が古いことがある。**迷ったら Apple の公式ドキュメントを確認する**（Xcode の MCP を入れていれば、ドキュメント検索が使える）。

## 全体

- 画面は SwiftUI で作る。UIKit を使うのはカメラを包む部分（`UIViewControllerRepresentable` = UIKit の画面を SwiftUI に入れるための包み）だけ
- 対応 OS より新しい API は `if #available(iOS 27, *)` で囲む
- Xcode の新規プロジェクトの既定のビルド設定（並行処理まわりを含む）を変えない。変えたいときは人に相談する
- 強制アンラップ（`!`）、`try!`、`fatalError` は、プレビュー用のサンプルデータ以外で使わない
- ビューの型名は `〜View` にする（例：`RecordListView`）。`List` や `Image` のように、SwiftUI の型と同じ名前を付けない
- 使う理由の申告が要る API（`UserDefaults`・ファイルの作成日時や更新日時・空き容量など）を新しく使うときは、`Kouiunodeiindayo/Resources/PrivacyInfo.xcprivacy` にも種類と理由コードを足す
- 整形（インデント・改行・空白）は swift-format（Xcode 同梱）に任せる。設定はリポジトリ直下の `.swift-format`。コミット時に pre-commit hook が自動でかけるので、手で揃えなくてよい。手動でかけるときの操作は `docs/setup.md`

## 状態の持ち方

- 画面の中だけの状態は `@State`。複数の画面で共有するものは `@Observable` のクラスにして `@Environment` で渡す
- `ObservableObject` / `@Published` / Combine は新しく書かない（古い書き方）
- 宣言時に初期値を持つ `@State` に、`init` の中で代入しない（Xcode 27 ではコンパイルエラーになる）
- 設定値は `@AppStorage`。キーの一覧は `docs/data-model.md`

## SwiftData

- データの形、ジャンルの持ち方、項目を足すときの決まりは `docs/data-model.md` が正。項目を足す・変えるときは、先にそちらを直す
- 読み方・書き方の決まり（読むときは `@Query`、書くときは `RecordStore`）は `docs/architecture.md` が正
- SwiftData の準備は、アプリの入口で `.modelContainer(for: Record.self)` を付けるだけにする。`ModelContainer` を自前で作らない（作成失敗時の `fatalError` を書かずに済む）。例外は `SampleData` のプレビュー用のメモリ上のものだけ
- メインスレッドの `modelContext` だけを使う。`@ModelActor`（別スレッドで SwiftData を使う仕組み）やバックグラウンドの `ModelContext` を作らない
- `#Predicate`（絞り込みの条件）の中には、`Genre.unsorted.rawValue` のような式や日付の計算を直接書けない。先に `let` で値に取り出してから使う
- 「今日」のように実行時に決まる条件は、ビューの `init` で `Query(filter:sort:)` を組み立てる。日付をまたいでも自動では更新されない点に注意する

## 写真

- 置き場所・ファイル名・サムネイルの決まりは `docs/data-model.md` が正
- ファイルの保存・読み込み・サムネイル作成・削除は `PhotoStorage` に集める。画面でファイルの場所を組み立てない
- 一覧のグリッドにフルサイズの写真を直接出さない。必ずサムネイルを使う（メモリ不足で落ちる）

## 操作と見た目

- スワイプでできる操作は、タップでもできるようにする（同じ関数を呼ぶ）
- ボタンや、押せるラベルには、VoiceOver（画面の読み上げ）用の `accessibilityLabel` を付ける
- 文字サイズは固定値にせず、利用者の文字サイズ設定に追従させる（独自フォントは `.custom(_:size:relativeTo:)`）
- 色・フォント・余白は `Design/Theme.swift` の定義を使う。画面ごとに値を直書きしない
- 縦書きは、固定の文言なら画像（デザイナーが作る）、日付など動く文字は1文字ずつ縦に積む。CoreText（文字を描く下位の仕組み）での本格的な縦書きは作らない

## プレビューとカメラ

- 画面ごとに `#Preview` を用意し、メモリ上だけのデータとサンプルデータで表示できるようにする
- カメラはシミュレータとプレビューで動かない。カメラを使う画面は、写真を外から渡せる形にして、カメラ無しでも表示を確認できるようにする
