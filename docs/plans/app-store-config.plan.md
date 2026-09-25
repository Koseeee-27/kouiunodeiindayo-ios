# 実装計画: App Store 提出のための設定

## 概要

App Store に出すビルドに要る設定（表示名・輸出コンプライアンス・Privacy Manifest）をそろえ、リリースのビルドにサンプルデータが混ざっていないことを確かめる。対応する Issue：#45。対応する機能：なし（提出の準備）。

## 前提・確認事項

- `project.pbxproj` は触らない。ビルド設定は `Config/Base.xcconfig` に書く。アプリ側の設定（pbxproj のターゲット）には `CFBundleDisplayName` と `ITSAppUsesNonExemptEncryption` のキーが無いので、xcconfig の値がそのまま効く
- `Kouiunodeiindayo/Resources/` は同期フォルダなので、ファイルを置くだけでアプリに入る
- 決めたこと（2026-09-25 にこうせいと確認。迷ったら戻す先）
  - **表示名は「こういうのでいいんだよ。」**。ホーム画面で「…」に切れても、この名前でいく
  - **`SampleData` は `#if DEBUG` で囲まない。** `#Preview` のコードはリリースのビルドにも入るので型は残るが、プレビューの外から呼ばれていなければ動かないので害はない。プレビューの外で使っていないことを grep で確かめ、結果を PR に書く
  - **`docs/rules/swift.md` に、Privacy Manifest を直す場面のルールを 1 行足す**（使う理由の申告が要る API を新しく使うとき）
  - 写真ライブラリの許可の文言（`NSPhotoLibraryUsageDescription` など）は、その機能（機能18・19）を入れるときに足す。今回は入れない
- 人が行うこと（この PR には入らない）：有料チームの `DEVELOPMENT_TEAM` への差し替え、Archive と Organizer の「Generate Privacy Report」での確認、ビルド番号を上げる作業、アプリアイコン

## ステップ

1. `Config/Base.xcconfig` — 末尾に 2 行とコメントを足す
   - `INFOPLIST_KEY_CFBundleDisplayName = こういうのでいいんだよ。`（ホーム画面のアイコンの下に出る名前。Xcode の General タブで編集すると pbxproj に書き戻されて二重になるので、ここで変える旨をコメントに書く）
   - `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`（独自の暗号化をしていないという申告。無いとアップロードのたびに質問される）
   - 確認方法：ビルドが通る
2. `Kouiunodeiindayo/Resources/PrivacyInfo.xcprivacy` — 新規作成（XML の plist）
   - `NSPrivacyTracking` = `false`
   - `NSPrivacyTrackingDomains` = 空の配列
   - `NSPrivacyCollectedDataTypes` = 空の配列
   - `NSPrivacyAccessedAPITypes` = 1 件：`NSPrivacyAccessedAPIType` = `NSPrivacyAccessedAPICategoryUserDefaults`、`NSPrivacyAccessedAPITypeReasons` = [`CA92.1`]（`StartTab.swift` の `@AppStorage` / `UserDefaults` がアプリ自身の設定を読み書きしている）
   - 他の申告が要る API（ファイルの作成日時・更新日時、空き容量、起動からの時間、キーボードの一覧）は使っていない。実装前に `grep -rnE "creationDate|modificationDate|contentModificationDate|attributesOfItem|attributesOfFileSystem|resourceValues|URLResourceKey|volumeAvailableCapacity|systemFreeSize|systemUptime|mach_absolute_time|activeInputModes|UITextInputMode|ProcessInfo|stat\(|statfs|getattrlist" Kouiunodeiindayo` で 0 件なのを確かめる（空き容量・ファイルの日時の低レベルな API も含める。セルフレビューで範囲を広げた）
   - 確認方法：`plutil -lint` が通る
3. `docs/rules/swift.md` — 「全体」の節に 1 行足す
   - 使う理由の申告が要る API（`UserDefaults`・ファイルの作成日時や更新日時・空き容量など）を新しく使うときは、`Kouiunodeiindayo/Resources/PrivacyInfo.xcprivacy` にも種類と理由コードを足す
4. `SampleData` の確認（コードは変えない）
   - `grep -rn "SampleData\|HomePreviewData\|SortPreviewData" Kouiunodeiindayo` の結果が、すべて `#Preview` の中か、`SampleData.swift`・`*PreviewData.swift` 自身であることを見る（`RootView.swift` の `#Preview` 2 つを含む）
5. 検証（`docs/rules/verification.md`）
   - Debug のビルド
   - Release のビルド：`xcodebuild -scheme Kouiunodeiindayo -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath <一時フォルダ> build`
   - できた `Kouiunodeiindayo.app` の `Info.plist` を `plutil -p` で見て、`CFBundleDisplayName` = `こういうのでいいんだよ。`、`ITSAppUsesNonExemptEncryption` = `false` を確かめる
   - `Kouiunodeiindayo.app/PrivacyInfo.xcprivacy` があり、`plutil -lint` が通ることを確かめる
   - シミュレータにアプリを入れ、ホーム画面のアイコンの下に表示名が出ているところを撮る。`.verification/45/` に置き、`notes.md` に操作と見るところを書く

## リスク

- `.xcprivacy` が同期フォルダからアプリに入らない：Release でビルドした `.app` の中を見て確かめる。入っていなければ止めて人に相談する（pbxproj を触らない）
- 表示名が長く、ホーム画面で「…」に切れる：決定済み。直さない
- `SampleData` の型自体はリリースのビルドに残る：プレビューからしか呼ばれないので動かない。決定済み

## 完成の確認方法

- Release のビルドの `Info.plist` に表示名と `ITSAppUsesNonExemptEncryption = false` が入っている
- `.app` に `PrivacyInfo.xcprivacy` が入っている
- シミュレータのホーム画面に表示名が出る（スクショ）
- `SampleData` がプレビューの外で使われていない（grep の結果）
- 実機での確認は不要。Archive と Privacy Report は、有料チームの承認後に人が行う
