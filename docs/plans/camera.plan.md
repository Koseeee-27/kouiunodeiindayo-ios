# 実装計画: カメラ（標準カメラの組み込み・撮って保存・仕分けへ）

## 概要

`Features/Camera/CameraView.swift` の仮ビューを、iPhone 標準のカメラ画面（`UIImagePickerController`）を包む本物に置き換え、撮った写真を `RecordStore` で保存して仕分け（仮ビュー）へ進める。対応する Issue：#15。対応する機能：機能1（起動したらカメラ）、機能2（撮って保存）、機能8（カメラの許可）、機能10（撮り直し。標準の確認画面で行う）。

カメラの要素と流れは `docs/screen-design.md` の「記録の流れ」「カメラ」、標準カメラを使う決定は `docs/adr/0003-camera.md` が正。この計画はそれをファイルと関数に落としたもの。

## 前提・確認事項

- #10（データ層）と #11（RootView と下タブ）はマージ済み。`RootView` は `isCameraShown` が true のとき `ZStack` に仮の `CameraView` を重ねているだけで、戻る手段が無い。この Issue で置き換える
- `project.pbxproj` は触らない。`Kouiunodeiindayo/` は同期フォルダなので、ファイルを置くだけで Xcode が認識する
- カメラの許可の文言（`INFOPLIST_KEY_NSCameraUsageDescription`）は `Config/Base.xcconfig` に入っている。触らない。許可の確認ダイアログは、`UIImagePickerController` をカメラで出したときに iPhone が自動で出す
- 許可を断られたときの案内は #21。この Issue では、断られていても落ちず、キャンセルでホームへ戻れればよい（標準カメラの中に黒い画面と「アクセスなし」の文言が出る）
- 自作カメラへの差し替えは #32（MVP の 4 画面が通ってから）。そのため **`CameraView` の口は `onPick: (UIImage) -> Void` と `onCancel: () -> Void` だけ**にし、中身を差し替えても `CameraFlowView` と `RootView` を触らずに済むようにする
- `Design/Theme.swift`（#23）はまだ無い。この Issue の画面は標準カメラと仮ビューだけなので、色・フォントは当てない
- 決めたこと（2026-09-23 にこうせいと確認済み。迷ったら戻す先）
  - **カメラは `fullScreenCover`（画面全体を覆うモーダル）で出す。** `RootView` の `ZStack` に埋め込む形はやめる。`UIImagePickerController` はモーダルで出す前提の部品で、埋め込みは Apple が保証していない。カバーなら下タブも自然に隠れる
  - **撮る → 保存 → 仕分けは、同じカバーの中で中身を切り替える**（`CameraFlowView` が `step` を持つ）。カメラのカバーを閉じてから仕分けのカバーを改めて出す形は、閉じ終わるのを待つ必要があり、ホームが一瞬見えてから仕分けが上がってくるのでやめる
  - **シミュレータで写真ライブラリに切り替える方法は、実行時の `UIImagePickerController.isSourceTypeAvailable(.camera)`。** Issue のコメントの `#if targetEnvironment(simulator)` ではなく実行時に判定する。シミュレータでは false になるので結果は同じで、加えて実機でスクリーンタイムの制限などでカメラが使えないときも落ちずに写真ライブラリへ逃げられる。コンパイル時の分岐も要らない
  - `CameraView` は SwiftData を知らない。保存（`RecordStore.add`）と画面の切り替え・エラー表示は `CameraFlowView` が持つ
  - `takenAt` は常に `.now`。シミュレータで古い写真を選んでも今日の記録になり、ホーム（今日の一枚。#14）の確認に使える。写真の撮影日時を使うのはカメラロールからの取り込み（機能18）のときだけ
  - キャンセル → ホームは、`fullScreenCover` の `onDismiss` ではなく `.onChange(of: isCameraShown)` で `page = .home` にする。`onDismiss` はカバーが閉じ終わってから呼ばれるので、一覧タブからカメラを開いてキャンセルすると、一覧が一瞬見えてからホームに変わる。`onChange` なら閉じ始める瞬間に切り替わる
  - 保存に失敗したら、標準の `alert`「保存できませんでした」を出し、OK でホームへ戻る。機能21（容量不足などの詳しい表示）は「余裕があれば」なので、ここではこの最小限の表示だけ。黙って失敗させない
  - 仮の `SortView` に「仕分け待ち n 枚」と最新の撮影日時を出し、「ホームへ」ボタンで閉じられるようにする。完成の条件「記録が保存され、撮影日時が付く」をシミュレータのスクショで示すため。#16 で丸ごと置き換える
  - 写真ライブラリの逃げ道のために `NSPhotoLibraryUsageDescription` は足さない。`UIImagePickerController` の `.photoLibrary` は別プロセスで動くので、写真ライブラリの許可が要らない（iOS 11 以降）
  - 仕分けを閉じる手段は `@Environment(\.dismiss)`。カバーの中で呼べばカバーが閉じる。#16 の本物の仕分けも「最後の1枚を仕分ける／仕分けを抜ける」で同じく `dismiss()` を呼ぶ。ホーム・一覧から仕分けを開くとき（#12・#14）も同じ `SortView` を自分のカバーに載せればよい

## ステップ

1. `Kouiunodeiindayo/Features/Camera/CameraView.swift` — 仮ビューを `struct CameraView: UIViewControllerRepresentable` に書き換える
   - `let onPick: (UIImage) -> Void`、`let onCancel: () -> Void`
   - `makeUIViewController`：`UIImagePickerController()` を作り、`sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary`、`delegate = context.coordinator`。`allowsEditing` は既定（false）のまま。`updateUIViewController` は空
   - `Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate`。`imagePickerController(_:didFinishPickingMediaWithInfo:)` で `info[.originalImage] as? UIImage` を `guard` し、取れたら `onPick(image)`。取れなければ `Logger` に残して `onCancel()`。`imagePickerControllerDidCancel(_:)` で `onCancel()`
   - **`picker.dismiss(animated:)` は呼ばない**。カバーの中身を `CameraFlowView` が切り替える（外す）ので、自分で閉じると二重になる
   - ファイル先頭のコメントに「シミュレータとカメラが使えない実機では写真ライブラリになる」「中身を自作カメラに差し替えるときは口（`onPick` / `onCancel`）を変えない（#32）」を書く
   - `#Preview` は `CameraView(onPick: { _ in }, onCancel: {})`（プレビューはシミュレータ上なので写真ライブラリが出る）／確認：ビルド
2. `Kouiunodeiindayo/Features/Sort/SortView.swift` — 仮ビューに、閉じる手段と保存の確認を足す
   - `@Environment(\.dismiss) private var dismiss`
   - 仕分け待ちの `@Query`：`#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、型のスコープで `private static let unsorted = Genre.unsorted.rawValue` に取り出してから `#Predicate<Record> { $0.genre == unsorted }`、並びは `\.takenAt` の新しい順（`docs/data-model.md` の「仕分け待ち」）
   - 中身：`Text("仕分け（仮。#16 で置き換える）")`、`Text("仕分け待ち \(records.count) 枚")`、最新1件があれば `Text(record.takenAt, format: .dateTime)`、`Button("ホームへ") { dismiss() }`（`accessibilityLabel` 付き）
   - `#Preview` は `.modelContainer(SampleData.makePreviewContainer())` と `.environment(\.photoStorage, SampleData.photoStorage)` を付ける／確認：プレビューで「仕分け待ち 1 枚」（サンプルデータの `unsorted` は1件）
3. `Kouiunodeiindayo/Features/Camera/CameraFlowView.swift` — 新規。カバーの中身。撮る → 保存 → 仕分けの流れを持つ
   - `enum Step { case camera, sort }`（`CameraFlowView` の中に入れ子で置く。`init(step:)` の引数に使うので private にはできない）
   - `@Environment(\.dismiss)`、`@Environment(\.modelContext)`、`@Environment(\.photoStorage)`
   - `@State private var step: Step`（初期値なし）、`@State private var isSaveFailed = false`。`init(step: Step = .camera)` で `_step = State(initialValue: step)`（`docs/rules/swift.md` の「宣言時に初期値を持つ `@State` に `init` で代入しない」に反しない書き方。`RootView` と同じ）
   - `body`：`switch step` で `.camera` なら `CameraView(onPick: { save($0) }, onCancel: { dismiss() }).ignoresSafeArea()`、`.sort` なら `SortView()`。`.alert("保存できませんでした", isPresented: $isSaveFailed) { Button("OK") { dismiss() } }`
   - `save(_ image: UIImage)`：`RecordStore(modelContext: modelContext, photoStorage: photoStorage).add(image: image, takenAt: .now)` を `do/catch`。成功で `step = .sort`、失敗で `Logger(category: "CameraFlowView")` に `error` を残して `isSaveFailed = true`
   - `#Preview("カメラ")` は `CameraFlowView()`、`#Preview("仕分け（仮）")` は `CameraFlowView(step: .sort)`。どちらも `SampleData` の container と photoStorage を付ける／確認：2つのプレビューが出る
4. `Kouiunodeiindayo/App/RootView.swift` — カメラをカバーで出す
   - `ZStack` の `if isCameraShown { CameraView() }` を消す（`ZStack` 自体も要らなくなるので外す）
   - `TabView` に `.fullScreenCover(isPresented: $isCameraShown) { CameraFlowView() }` を付ける
   - `.onChange(of: isCameraShown) { _, isShown in if !isShown { page = .home } }`。コメントに「キャンセルと仕分け終了はどちらもホームへ（`docs/screen-design.md` の「画面のつながり」）。`onDismiss` だと閉じ終わってから切り替わり、一覧が一瞬見える」と書く
   - `select(_:)`、`RootTabBar(selected: isCameraShown ? .camera : page)`、`init(startTab:)`、2つの `#Preview` は変えない／確認：ビルド。プレビュー「カメラから開く」でカバー（シミュレータなので写真ライブラリ）が上がる
5. `docs/architecture.md` — 「フォルダ構成」の `Features/Camera/` に `CameraView.swift`（標準カメラの包み。口は `onPick` / `onCancel`）と `CameraFlowView.swift`（撮る → 保存 → 仕分けの切り替え。カバーの中身）を足す。「ホーム・一覧・カメラの行き来は下タブ」の箇条書きに「カメラは `RootView` が `fullScreenCover` で出す。撮ったあとの仕分けも同じカバーの中で `CameraFlowView` が切り替える。仕分けは `dismiss()` で閉じ、閉じるとホームに戻る」を添える／確認：文書だけ
6. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/15/` に残す（git には入れない。PR には写真と文章で貼る）
   - `01-起動直後-写真ライブラリ.png`：シミュレータで起動。カメラの代わりに写真ライブラリが全画面で出て、下タブが隠れている
   - `02-写真を選ぶ-仕分け仮-1枚.png`：写真を1枚選ぶ。「仕分け待ち 1 枚」と今日の日時が出る
   - `03-ホームへ-ホーム.png`：「ホームへ」を押す。ホームに戻り、下タブの選択が「ホーム」
   - `04-一覧タブからカメラ-キャンセル-ホーム.png`：一覧タブ → 下タブ「カメラ」→ キャンセル。一覧ではなくホームに戻る
   - `05-開き直して再度選ぶ-2枚.png`：アプリを終了して開き直し、もう1枚選ぶ。「仕分け待ち 2 枚」（保存が残っている）
   - `06-Photosフォルダの一覧.txt`：`xcrun simctl get_app_container booted <bundle id> data` の `Library/Application Support/Photos/` に `<id>.jpg` と `<id>_thumb.jpg` が2組ある（bundle id は `Config/Base.xcconfig` と `Local.xcconfig` から求める）
   - `07-文字サイズ最大-仕分け仮.png`：文字サイズを最大にしても仮ビューが切れない
   - `preview-CameraFlowView-仕分け.png`、`preview-SortView.png`
   - `notes.md` に写真ごとの「操作」と「見るところ」を表で書く。#11 の `notes.md` と同じ形
7. 実機での確認（こうせいが行う。AI だけで「確認済み」にしない）。結果は PR の「実機での確認」に書く
   - アプリを一度削除してから入れる → 起動直後に iPhone の許可ダイアログが出て、文言が「ご飯の写真を撮って記録するために、カメラを使います。」になっている
   - 許可 → 標準カメラ → 撮る → 標準の確認画面で「再撮影」→ もう一度撮る → 「写真を使用」→ 仕分け（仮）に「仕分け待ち 1 枚」と今の日時
   - 「ホームへ」→ ホーム。下タブ「カメラ」→ キャンセル → ホーム
   - アプリを終了して開き直す → カメラ → 撮る → 「仕分け待ち 2 枚」（写真ファイルが残っている）
   - 起動直後にホームが一瞬見えるか、カバーが下から上がる動きが気になるか（下の「リスク」）
8. `docs/rules/self-review.md` のセルフレビューを回してから PR（`Closes #15`）。PR の題名は日本語

## リスク

- **起動時のカバーの動き**：`isCameraShown` が最初から true なので、ホームの上にカバーが下から上がる動きが一瞬見える（1フレームのホーム＋約 0.3 秒の動き）。標準カメラ自体の起動待ち（黒い画面）と重なるので MVP では許容する。実機で気になれば、`RootView` の `init` で true にするのをやめ、`.onAppear` で `withTransaction(Transaction(animation: nil))`（`disablesAnimations = true`）の中で `isCameraShown = true` にして動きだけ消す手を試す。この場合も最初の1フレームはホームになる（#11 の計画で避けた点だが、カバーにした時点で避けられない）
- **`fullScreenCover` の中の環境値**：`modelContext`（`.modelContainer(for:)` 由来）と `photoStorage` はカバーの中にも引き継がれるはず。引き継がれず保存で落ちるなら、`RootView` のカバーの中身に `.modelContainer` を付け直すのではなく、原因を Apple の公式ドキュメントで確かめてから直す
- **iOS 26 での `.photoLibrary`**：`UIImagePickerController` の写真ライブラリは iOS 14 から `PHPickerViewController` が推奨だが、廃止はされていない。もしシミュレータで写真ライブラリの許可を求められる・落ちるなら、逃げ道だけ `PHPickerViewController` に替える（`Config/Base.xcconfig` に `NSPhotoLibraryUsageDescription` を足すのは、製品のアプリにも文言が載るので最後の手段）
- **「写真を使用」直後の待ち**：2000px への縮小がメインスレッドで 0.1〜0.3 秒走る。撮影直後だけなので #10 の判断どおり非同期にしない。実機でもたつくなら別 Issue
- **許可を断られている実機**：標準カメラの中に黒い画面と英語の文言が出る。キャンセルでホームへ戻れる。案内は #21
- **写真の向き**：カメラの `originalImage` は `imageOrientation` を持つが、`PhotoStorage` は `draw(in:)` で描き直すので、保存される JPEG は正しい向きになる。実機で横倒しになっていたら `PhotoStorage` 側を見る
- **`didFinishPicking` で画像が取れない**：カメラ・写真ライブラリのどちらでも通常は取れる。取れなかったらログを残してキャンセル扱い（ホームへ）にし、落とさない
- **ホーム（#14）の「撮るボタン」からカメラを開く**：この Issue では作らない。#14 で `RootView` の `isCameraShown` を立てる口（クロージャか環境値）を足す
- **`SortView` の `dismiss()`**：この Issue ではカバーの中だけで使う。#12・#14 で仕分けをカバー以外の形（`NavigationStack` の push など）で開いても、`dismiss()` はその形に合わせて閉じるので変えなくてよい

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- シミュレータで、起動直後に写真ライブラリが全画面で出て下タブが隠れる。写真を選ぶと仮の仕分けに「仕分け待ち 1 枚」と今日の日時が出る。「ホームへ」でホームに戻り、下タブの選択もホーム
- シミュレータで、一覧タブから下タブ「カメラ」→ キャンセルで、一覧ではなくホームに戻る
- シミュレータで、アプリを終了して開き直しても記録が残っている（もう1枚選ぶと「2 枚」）。`Application Support/Photos/` に写真とサムネイルが2組ある
- `CameraFlowView` のプレビュー2つと `SortView` のプレビューが出る
- 実機での確認：**要る**（ステップ 7。許可ダイアログの文言、撮る → 撮り直す → 保存、キャンセル → ホーム、終了して開き直しても残る）。実機で確かめるまで Issue を閉じない
