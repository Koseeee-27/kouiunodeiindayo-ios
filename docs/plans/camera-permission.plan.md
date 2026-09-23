# 実装計画: カメラの許可を断られたときの案内

## 概要

カメラのカバー（`CameraFlowView`）で、カメラを出す前にカメラの許可の状態を見て、断られている・制限されているときは標準カメラの代わりに案内画面を出す。案内画面から設定アプリを開く・アルバムから選んで仕分けへ進む・ホームへ戻る、ができる。対応する Issue：#21。対応する機能：機能9（許可を断られたときの案内）、機能18（カメラロールから取り込む。案内画面の入口だけ）。

要素は `docs/screen-design.md` の「カメラの許可を断られたときの案内」「画面のつながり」が正。この計画はそれをファイルと関数に落としたもの。

## 前提・確認事項

- #15（PR #33）はマージ済み。`CameraFlowView` が撮る → 保存 → 仕分けを `step` で切り替えている。`CameraView` は `UIImagePickerController` の包みで、口は `onPick` / `onCancel`
- 今の `CameraView.sourceType` は、実機では `isSourceTypeAvailable(.camera)`（カメラの有無）しか見ない。許可を断られていると標準カメラが真っ黒でシャッターが効かない（#15 の実機確認で判明）
- `project.pbxproj` は触らない。`Features/Onboarding/` はまだ無いので、フォルダを作ってファイルを置くだけでよい
- カメラの許可の文言（`NSCameraUsageDescription`）は `Config/Base.xcconfig` にある。触らない。写真ライブラリの許可も足さない（`UIImagePickerController` の `.photoLibrary` は別プロセスで動くので許可が要らない。#15 の計画のとおり）
- 決めたこと（2026-09-23 にこうせいと確認済み。迷ったら戻す先）
  - **許可の状態（`AVCaptureDevice.authorizationStatus(for: .video)`）で最初の画面を決める。**
    - `.authorized` → カメラ
    - `.denied` → 案内（断られた用の文言）
    - `.restricted` → 案内（制限されている用の文言）
    - `.notDetermined` → **アプリから `AVCaptureDevice.requestAccess(for: .video)` を呼んで iOS の許可ダイアログを出し、答えで振り分ける**（許可 → カメラ、許可しない → 案内）。標準カメラに任せると、ダイアログで「許可しない」を押した瞬間に真っ黒な画面になるため。ダイアログの後ろは無地（黒）の画面
    - 将来 iOS に新しい状態が増えたとき（`@unknown default`）はカメラにする（今までどおりの動き）
  - **振り分けはシミュレータでも効かせる。** シミュレータの `.camera` の段は今どおり写真ライブラリになる（`CameraView.sourceType`）。こうすると `xcrun simctl privacy booted revoke camera <bundle id>` で案内画面をシミュレータで確認できる
  - **アルバムから選ぶ**は、`CameraView` に `forcesPhotoLibrary: Bool = false` を足して使い回す。true なら実機でも `.photoLibrary`。選んだら撮った写真と同じ `save` → 仕分け
  - **アルバムでキャンセルしたら案内に戻る**（ホームではない）
  - **アルバムから選んだ写真の `takenAt` は、撮った写真と同じ `.now`（選んだ時刻）。** 写真の撮影日時を読むのは機能18（カメラロールからの取り込み）の本体で行う。許可なしの写真選択では撮影日時が確実に取れず、古い日時を入れると仕分け待ちの並び（`createdAt` 順にするか。`docs/data-model.md`）も同時に決める必要があるため。`docs/data-model.md` に一文足し、撮影日時の読み取りは別 Issue にする
  - **制限されているときも「設定を開く」は残し、文言だけ変える**（Issue のとおり）
  - 文言：
    - 見出し：「カメラが使えません」
    - 断られたとき：「カメラへのアクセスがオフになっています。設定アプリで「カメラ」をオンにすると撮れます。」
    - 制限されているとき：「スクリーンタイムなどでカメラが制限されているため、撮れません。アルバムから選んで記録できます。」
    - ボタン：「設定を開く」「アルバムから選ぶ」「ホームへ」
  - 設定アプリでカメラをオンにしてアプリに戻ると、iOS がアプリを終了させるので、開き直し（いつも通りの画面）になる。戻ってきたときに状態を見直す処理は作らない
  - 見た目は「最低限」。標準の部品だけで作り、`Theme` は当てない
  - 実装で足したこと（2026-09-23。計画にない軽微なもの）
    - `CameraFlowView` の `#Preview("カメラ")` は `CameraFlowView(step: .camera)` にした。`step` を省くと許可の状態で決まり、プレビューでは未確認なので黒い画面（`.requestingAccess`）になるため
    - `.library` は `case library(isRestricted: Bool)` にした（ステップ 3 の2案のうち、`Step` に持たせるほう）
    - 案内画面は、中身が短いときに縦の真ん中に来るよう `ScrollView` に `.defaultScrollAnchor(.center, for: .alignment)` を付けた
    - シミュレータの確認に、計画の一覧に無い 09（許可をリセットして起動 → ダイアログ）・10（「許可しない」→ すぐ案内）を足した
    - 実機確認のあと（2026-09-23 にこうせいと決定）：アルバムから選んだ写真の `takenAt` は、暫定ではなく**ずっと選んだ時刻**にする（シンプルなため。昔の写真は機能13 で日付を直す）。`docs/data-model.md` と `docs/requirements.md`（機能13・18）を揃え、撮影日時を読む Issue（#48）は閉じる
    - セルフレビューを受けて：制限されているときは「アルバムから選ぶ」を目立つボタン（`.borderedProminent`）にし、「設定を開く」を控えめ（`.bordered`）にした（制限はこのアプリの設定では外せないため。文言とボタンの数は変えない）。見出しに `.isHeader`、「設定を開く」に `accessibilityHint` を付けた

## ステップ

1. `Kouiunodeiindayo/Features/Camera/CameraView.swift` — 写真ライブラリを強制する引数を足す
   - `var forcesPhotoLibrary = false` を `onPick` / `onCancel` と並べて持つ（呼び出し側は `CameraView(forcesPhotoLibrary: true, onPick:..., onCancel:...)`。省略すると今までどおり）
   - `private static var sourceType` をインスタンスの `private var sourceType` にし、`forcesPhotoLibrary` が true なら `.photoLibrary` を返す。それ以外は今の分岐（シミュレータは `.photoLibrary`、実機は `isSourceTypeAvailable(.camera)`）のまま。既存のコメント（iOS 27 のシミュレータ、`API_TO_BE_DEPRECATED`）は残す
   - 型のコメントに「許可の確認は呼び出し側（`CameraFlowView`）が行う。ここでは見ない」を足す
   - 確認：ビルド
2. `Kouiunodeiindayo/Features/Onboarding/CameraAccessGuideView.swift` — 新規。案内画面
   - `let isRestricted: Bool`、`let onPickFromLibrary: () -> Void`、`let onGoHome: () -> Void`
   - `@Environment(\.openURL)` で `URL(string: UIApplication.openSettingsURLString)` を開く（このアプリの設定画面が開く）
   - 中身：アイコン（`camera` 系の SF Symbol、`accessibilityHidden`）、見出し、本文（`isRestricted` で上の文言を切り替え）、ボタン3つ。縦に並べ、文字サイズ最大でも切れないよう `ScrollView` に載せる。主ボタンは「設定を開く」（`.borderedProminent`）、ほかは `.bordered` / 文字だけ、程度でよい
   - `#Preview("断られた")`、`#Preview("制限されている")`
   - 確認：プレビュー2つ
3. `Kouiunodeiindayo/Features/Camera/CameraFlowView.swift` — 許可で振り分ける
   - `enum Step` を `requestingAccess`、`camera`、`accessGuide(isRestricted: Bool)`、`library`、`sort` にする（`Equatable`）
   - `init(step: Step? = nil)`：`nil` なら `Self.initialStep()` で決める。`initialStep()` は上の「決めたこと」の表どおり（`.notDetermined` → `.requestingAccess`）。`_step = State(initialValue: ...)` の書き方は今のまま
   - `body` の `switch`：
     - `.requestingAccess`：`Color.black.ignoresSafeArea()` に `.task { await requestAccess() }`
     - `.camera`：今のまま
     - `.accessGuide(let isRestricted)`：`CameraAccessGuideView(isRestricted:, onPickFromLibrary: { step = .library }, onGoHome: { dismiss() })`
     - `.library`：`CameraView(forcesPhotoLibrary: true, onPick: { save($0) }, onCancel: { step = .accessGuide(isRestricted: ...) })`。キャンセルで戻る先の `isRestricted` を失わないよう、`.library` に `isRestricted` を持たせる（`case library(isRestricted: Bool)`）か、案内に来たときの値を `@State` に取っておく。どちらでもよいが、`Step` に持たせるほうが状態が1か所で済む
     - `.sort`：今のまま
   - `requestAccess()`：`let granted = await AVCaptureDevice.requestAccess(for: .video)` のあと `step = granted ? .camera : .accessGuide(isRestricted: false)`。`@MainActor` の `View` の中なので `step` の代入はメインスレッドで行われる
   - `save` のコメント「写真の撮影日時を使うのはカメラロールからの取り込み（機能18）だけ」を、「案内からアルバムで選んだ写真も今は `.now`（#21。撮影日時を読むのは機能18 の本体）」が分かる形に直す
   - `#Preview` に「案内（断られた）」`CameraFlowView(step: .accessGuide(isRestricted: false))` を足す。既存の2つは `step:` の型が変わっても通るように直す
   - 確認：ビルド、プレビュー3つ
4. `docs/architecture.md` — 「フォルダ構成」の `Onboarding/` に `CameraAccessGuideView.swift ← カメラの許可を断られた・制限されているときの案内。設定を開く・アルバムから選ぶ・ホームへ` を足す。`Camera/` の `CameraFlowView.swift` の説明に「許可の状態で、カメラか案内かを振り分ける」を足す
   `docs/data-model.md` — `takenAt` の行の「カメラロールから取り込んだ写真は、写真の撮影日時を使う（機能18）」のあとに「（許可を断られたときの案内からアルバムで選んだ写真は、今は選んだ時刻。#21）」を足す
   確認：文書だけ
5. `docs/rules/verification.md` の 1（ビルド）と 3（表示の確認）。スクショを `.verification/21/` に残す（git には入れない）。bundle id は `Config/Base.xcconfig` と `Config/Local.xcconfig` から求める
   - `01-許可を取り消して起動-案内.png`：`xcrun simctl privacy booted revoke camera <bundle id>` のあとアプリを起動。案内（断られた用の文言）が全画面で出て、下タブが隠れている
   - `02-アルバムから選ぶ-写真ライブラリ.png`：「アルバムから選ぶ」を押す。写真ライブラリが出る
   - `03-アルバムでキャンセル-案内.png`：キャンセルで案内に戻る
   - `04-写真を選ぶ-仕分け.png`：もう一度「アルバムから選ぶ」→ 写真を選ぶ → 仕分けに進み、1枚増えている
   - `05-ホームへ-ホーム.png`：仕分けを抜けたあと下タブ「カメラ」→ 案内 →「ホームへ」でホームに戻る
   - `06-設定を開く-設定アプリ.png`：「設定を開く」でこのアプリの設定画面が開く（シミュレータで開けなければ、その旨を notes.md に書く）
   - `07-文字サイズ最大-案内.png`：文字サイズを最大にしても案内が切れない
   - `08-許可を戻して起動-写真ライブラリ.png`：`xcrun simctl privacy booted grant camera <bundle id>` のあと起動すると、今までどおり写真ライブラリ（シミュレータのカメラの代わり）が出る
   - `preview-CameraAccessGuideView-断られた.png`、`preview-CameraAccessGuideView-制限されている.png`
   - `notes.md` に写真ごとの「操作」と「見るところ」を表で書く
6. 実機での確認（こうせいが行う。AI だけで「確認済み」にしない）。結果は PR の「実機での確認」に書く
   - アプリを削除して入れ直す → 許可のダイアログで「許可しない」→ すぐ案内画面になる（真っ黒なカメラにならない）
   - 「アルバムから選ぶ」→ 写真を選ぶ → 仕分けに進む
   - 「ホームへ」→ ホーム
   - 「設定を開く」→ このアプリの設定画面 → カメラをオン → アプリに戻る → 開き直してカメラが使える
   - 入れ直して「許可」→ 今までどおり標準カメラで撮れる
7. `docs/rules/self-review.md` のセルフレビューを回してから PR（`Closes #21`）

## リスク

- **`.photoLibrary` の非推奨予告**：iOS 27 SDK で `API_TO_BE_DEPRECATED`。警告が出たら、アルバムの段だけ `PHPickerViewController` に替える（`CameraView` の既存コメントの方針）。今回は替えない
- **`requestAccess` のダイアログの後ろ**：黒い画面の上にダイアログが出る。カバーが下から上がる動きと重なる。気になれば実機確認のときに見る
- **ダイアログ中にアプリを閉じる**：次に開いたときは状態が `.notDetermined` のままなので、もう一度ダイアログが出る。問題なし
- **`.task` の二重実行**：`.requestingAccess` の段が作り直されると `requestAccess` がもう一度呼ばれるが、ダイアログは iOS が1回しか出さず、2回目はすぐ答えが返るので問題なし
- **制限されている状態**：実機でもシミュレータでも作りにくい。文言はプレビューで確認する
- **シミュレータで「設定を開く」**：シミュレータの設定アプリでも開けるはず。開けなくても実機で確認する

## 完成の確認方法

- ビルドが通る（verification.md の 1）
- シミュレータで、カメラの許可を取り消して起動すると案内が出る。アルバムから選ぶ → 仕分け、キャンセル → 案内、ホームへ → ホーム
- 許可を戻すと、今までどおり写真ライブラリ（シミュレータのカメラの代わり）が出る
- `CameraAccessGuideView` のプレビュー2つ、`CameraFlowView` のプレビュー3つが出る
- 実機での確認：**要る**（ステップ 6。許可しない → すぐ案内、設定を開く、アルバム → 仕分け）。実機で確かめるまで Issue を閉じない
