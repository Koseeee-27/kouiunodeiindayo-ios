# 実装計画: 撮った写真を写真アプリにも保存する

## 概要
アプリのカメラで撮った写真を、アプリに記録したのと同時に写真アプリ（カメラロール）にも保存する。設定でオン・オフできる（初期設定はオン）。対応する Issue：#138。対応する機能番号：`docs/requirements.md` の機能19

## 前提・確認事項
- 許可は「追加だけ」（`PHAccessLevel.addOnly`）。専用のアルバムは作らない
- 保存するのはカメラで撮った写真だけ。アルバムから選んだ写真（カメラの許可を断られたときの案内から選ぶ・ホームの取り込み）は保存しない
- 許可を断られた・保存に失敗したときは、写真アプリへの保存だけを飛ばす（ログだけ。アラートは出さない）
- 使う API：`PHPhotoLibrary.requestAuthorization(for:)`（iOS 14）、`PHPhotoLibrary.performChanges(_:)` の async 版（iOS 15）、`PHAssetChangeRequest.creationRequestForAsset(from:)`。どれも iOS 26 で使える

## ステップ
1. `docs/data-model.md` — 設定値の表に `savesToPhotoLibrary`（`Bool`、初期設定 `true`）を足す
2. `Config/Base.xcconfig` — `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` を 1 行足す（文言の正は `docs/screen-design.md` のカメラの項）
3. `Kouiunodeiindayo/Features/Camera/PhotoLibrarySaver.swift` — キー・初期値・保存するかの判定（純粋な関数）・保存（許可を聞いてから追加。失敗はログだけ）
4. `Kouiunodeiindayo/Features/Camera/CameraFlowView.swift` — `RecordStore` に追加したあと、カメラから撮ったときだけ裏で保存する
5. `Kouiunodeiindayo/Features/Settings/SettingsView.swift` — 「撮った写真を写真アプリにも保存する」のトグル
6. `KouiunodeiindayoTests/PhotoLibrarySaverTests.swift` — 判定のテスト
7. `docs/requirements.md`・`docs/screen-design.md` — 機能19 の行、設定とカメラの要素

## リスク
- 初めての許可の確認は、撮った直後（仕分けの画面の上）に出る。撮る流れは止めない
- 写真アプリへの保存は実機でしか確かめられない

## 完成の確認方法
- テスト（判定）・全体のテスト
- 設定のプレビュー
- 実機：初めて撮ったときに確認が出る／許可すると写真アプリに入る／設定でオフにすると入らない／断っても撮る・仕分けは止まらない
