# 0003: MVP は iPhone 標準のカメラ画面を使う

- 状態：採用
- 日付：2026-09-21

## 決めたこと

- MVP のカメラは、iPhone 標準のカメラ画面（`UIImagePickerController`）を SwiftUI に組み込んで使う
- 撮る → 標準の確認画面（再撮影／写真を使用）→ 仕分け、の流れにする（`docs/requirements.md` の前提どおり）
- 独自のカメラ画面（確認を挟まずに仕分けへ移る、見た目を作り込む）は、MVP が通ってから検討する

## 理由

- 標準のカメラ画面は、フラッシュ・内側カメラ・ズームが最初から付いていて、実装が短い
- 独自カメラ（AVFoundation）は、権限・撮影の準備・向き・並行処理が絡み、初めてのモバイル開発には重い
- こだわる画面はホームと仕分け。カメラは「最低限」（`docs/screen-design.md`）

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| 最初から独自カメラ（AVFoundation） | 重い。シミュレータで動かず、AI による確認も効かない |
| 標準カメラに自前のボタンを重ねる（`cameraOverlayView`） | 中間案。確認画面を省けるかが未確認。MVP の後で試す候補 |

## 影響・注意

- カメラはシミュレータで動かない（作り方の決まりは `docs/rules/swift.md`）
- カメラを使う理由の文言（`NSCameraUsageDescription`）が必須。新しい Xcode のプロジェクトには Info.plist のファイルが無いので、ビルド設定（`Config/Base.xcconfig` の `INFOPLIST_KEY_NSCameraUsageDescription`）に書く。文言の正は `docs/screen-design.md` のカメラの項
- 日本で売られている iPhone は、シャッター音を消せない。独自カメラにしても同じ。撮影の瞬間に自前の効果音を重ねると、二重に鳴る
- 標準のカメラ画面は縦向きのみで、見た目はほぼ変えられない

## 出典

- https://developer.apple.com/documentation/uikit/uiimagepickercontroller
- https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app
- https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/isshuttersoundsuppressionsupported
- https://www.itmedia.co.jp/mobile/articles/2501/28/news115.html
