# 実装計画: アルバムから写真をまとめて取り込み、食事らしいものだけを仕分け待ちに入れる

## 概要

ホームから写真を最大 30 枚まとめて選び、端末の Vision で食事らしいものだけを仕分け待ちに入れて、取り込んだ写真だけの仕分けに進む。記録の日付は写真の撮影日時にする。仕分けの上に「取り込み n 枚 ／ 除外 m 枚」を小さく出す。提案（点線・チップ）は #82・#83 の仕組みがそのまま動く。対応する Issue：#102（親 #86）。対応する機能：`docs/requirements.md` の機能18（カメラロールから取り込む）。

ブランチは `feat/102-photo-import`。main から作り直し済み（#100 ホーム画面の整理・#101 仕分けの提案・#99 料理のタグのしきい値はマージ済みで、このブランチに入っている）。

## 決めたこと（全部推奨、2026-09-27 こうせい確認）

本文の「要判断 n」は、この番号を指す。

1. **ホームの入口**：右上の設定のアイコンの左に、同じ大きさ（`.title3`）・同じ色（`Theme.textSecondary`）の写真のアイコン（`photo.on.rectangle`）を並べる。いつも同じ場所。読み上げは「アルバムから取り込む」
2. **取り込み中の見せ方**：ホームの上に半透明の幕を重ね、真ん中に回るマークと「取り込み中 3 / 12」。終わったら幕を消して仕分けを開く。取り込み中は触れない
3. **「取り込み n 枚 ／ 除外 m 枚」**：仕分けの上の行（✕ と「あと n 枚」）のすぐ下に、`Theme.textSecondary` の `.caption` で真ん中に 1 行。取り込みから入った仕分けの間ずっと出す。除外が 0 のときも「除外 0 枚」を出す
4. **読めなかった写真**：除外に入れず、1 枚以上あるときだけ「／ 読めなかった k 枚」を同じ行に足す
5. **食事らしい写真が 0 枚のとき**：仕分けを開かず、ホームのままアラート「食事の写真が見つかりませんでした」、本文「除外 m 枚」、ボタン「OK」
6. **撮影日時が入っていないとき**：取り込んだ時刻にする（直すのは機能13）
7. **Vision が失敗した写真**：食事扱いで取り込む
8. **しきい値**：`food` などのラベルが 0.30 以上を食事とする。実機で外れを見てこうせいが直す値として扱う
9. **仕様の食い違い**：`docs/data-model.md` はこの PR で直す。`docs/requirements.md` と `docs/screen-design.md` は下の「ドキュメント」の下書きを PR に書いて、こうせいが直す。カメラの許可を断られたときの「アルバムから選ぶ」（`CameraFlowView` の `.library`）はこの Issue では触らない

## 調べたこと（Apple の公式ドキュメントで確認。Xcode 27 の DocumentationSearch）

### 写真を選ぶ：`PhotosPicker`（SwiftUI）に権限は要らない

- `PhotosPicker(selection: Binding<[PhotosPickerItem]>, maxSelectionCount:selectionBehavior:matching:preferredItemEncoding:label:)` で複数選択できる。`maxSelectionCount: 30`、`matching: .images`
- 公式の説明：「利用者が選んだ項目だけを明示的に渡すので、写真ライブラリへのアクセスの許可は要らない」（`photosPicker(isPresented:selection:maxSelectionCount:…)` の Discussion）。**許可の確認画面は出ない。`NSPhotoLibraryUsageDescription` の文言も要らない**
- `PhotosPickerItem.itemIdentifier` は「写真ライブラリを渡さずに作ったピッカーでは `nil`」。`photoLibrary: .shared()` を渡すと識別子は取れるが、その識別子で `PHAsset`（撮影日時 `creationDate` を持つ）を取り出すには、写真ライブラリの許可が要る（PhotoKit「Fetching Assets」の Important）。**この道は使わない**
- 中身は `item.loadTransferable(type: Data.self)` で、元の画像ファイルのデータ（HEIC か JPEG）として受け取る。iCloud にしか無い写真は、そこで取りに行く。通信できないと失敗する（`PhotosPickerItem` の Overview）
- `preferredItemEncoding: .current` にすると、HEIC を JPEG に変換せずにそのまま渡る（変換の時間を省く）

### 撮影日時：画像データの EXIF から読む（権限不要）

- `CGImageSourceCreateWithData` → `CGImageSourceCopyPropertiesAtIndex(source, 0, nil)` の `kCGImagePropertyExifDictionary` の中の `kCGImagePropertyExifDateTimeOriginal`（撮影日時。`"2026:09:26 12:34:56"` の形の文字列。時差なし）と `kCGImagePropertyExifOffsetTimeOriginal`（時差。`"+09:00"`。iPhone で撮った写真には入っている）
- 時差があればそれで、無ければ端末の時間帯（`TimeZone.current`）で `Date` にする。どちらも読めなければ `nil`（要判断 6）
- **注意**：iOS 26 以降に `photosPickerMetadataOptions(_:)`（`PHPickerMetadataOptions`）が足されている。既定で位置などのメタデータを落とすかは、ドキュメントに書かれていない。**実機で、ピッカーから受け取ったデータに `DateTimeOriginal` が残っているかを最初に確かめる**（ステップ 2 の確認）。残っていなければ、`PHPickerMetadataOptions` の中身を Xcode のドキュメントで確かめて付ける。それでも取れなければ止まってこうせいに相談する（写真ライブラリの許可を取る案に替える。そのときの確認画面の文言の下書き：「過去のご飯の写真の撮影日を記録に使うために、写真へのアクセスを使います。」）

### 30 枚の処理時間とメモリ

- **メモリ**：48MP の写真を `UIImage(data:)` でそのまま描くと 1 枚 190MB 前後（8064×6048×4 バイト）になり、落ちる。`CGImageSourceCreateThumbnailAtIndex` で、長辺 2000px（保存する大きさ）に**読みながら縮める**（`kCGImageSourceCreateThumbnailFromImageAlways: true`・`kCGImageSourceThumbnailMaxPixelSize: 2000`・`kCGImageSourceCreateThumbnailWithTransform: true` で向きも直す）。1 枚あたり 2000×1500×4 = 12MB。元のデータ（HEIC で 2〜5MB）と合わせても、**1 枚ずつ処理すれば、ピークは 50MB 以下**の見込み
- **時間**（見込み。実機で測って notes.md に書く）：データの受け取り 0.1〜0.5 秒（iCloud から取りに行くと数秒）＋縮小 0.05〜0.1 秒＋Vision 0.1〜0.3 秒＋保存（JPEG 2 枚の書き出し）0.1 秒 ＝ 1 枚 0.3〜1 秒、**30 枚で 10〜30 秒**。だから進み具合を出す（要判断 2）
- 1 枚ずつ順に処理する（同時に何枚も縮めない）。受け取りが遅いときだけ、受け取りを 2 枚ずつ先に始める（リスク参照。最初は入れない）
- Vision（`ClassifyImageRequest`）は、縮めた `CGImage` をそのまま渡せる（`perform(on: CGImage)`。#82 の計画で確認済み）。ファイルに書く前に判定できるので、除外した写真はファイルを作らない
- 保存（`RecordStore.add`）はメインスレッドで JPEG を書き出す（1 枚 0.05〜0.1 秒）。30 枚で合計 2〜3 秒メインが止まるが、1 枚ごとに進み具合の描き直しが入るので、固まって見えないはず。固まるようなら「リスク」

### 食事らしいかの判定（Vision のラベル）

- 実機と同じ Vision（Mac）で無料素材 6 枚に掛けたラベル（`server/scripts/real-labels.tsv`）では、料理の写真には全部 `food` が出ていた（唐揚げ 0.36・うどん 0.65・天ぷら 0.72・親子丼 0.50・味噌汁 0.72・弁当 0.70）
- 飲み物・デザートだけの写真は `food` が弱いことがあるので、`food` に加えて `drink`・`beverage`・`dessert`・`baked_goods` と、`Tag.visionLabels`（料理名のラベル。`ramen`・`coffee`・`cake` など）のどれかが **0.30 以上**なら食事とする（要判断 8）
- 判定は `[ImageLabel]` を受け取る純粋な関数にして、テストで `real-labels.tsv` の 6 枚と「食べ物でない」例を確かめる

## 前提・確認事項

- `project.pbxproj` は触らない。新しいファイルは同期フォルダ（`Kouiunodeiindayo/`・`KouiunodeiindayoTests/`）に置くだけ
- `PhotosUI`・`ImageIO` は OS の一部で、外部ライブラリではない。iOS 26 で使える（`PhotosPicker` は iOS 16〜、`ClassifyImageRequest` は iOS 18〜）。`#available` は要らない
- 許可が要らないので、`Config/Base.xcconfig`・`PrivacyInfo.xcprivacy` は変えない（ImageIO で EXIF を読むのは申告の要る API ではない）
- ビルド設定の既定は `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。重い処理（データの縮小・EXIF・Vision）は `@concurrent nonisolated` の関数に置く（`ImageLabeler` と同じ書き方）
- SwiftData はメインスレッドだけ。裏の処理からは `CGImage`・`Date`・`[ImageLabel]` だけを返し、`RecordStore.add` はメインで呼ぶ
- 提案の問い合わせは、取り込みからは頼まない。仕分けの画面が開いたときに `suggestedAt == nil` の写真を並び順に頼む（今の `SortView.onAppear`）ので、画面に先に出る写真から提案が埋まる。取り込み側からも頼むと、取り込み順（選んだ順）で待ち行列に入り、先頭の写真の提案が遅れる
- #103（おまかせ仕分け）も `SortView` を触る。この Issue で `SortView` に足すのは「取り込みの id で絞る」と「件数の 1 行」だけにして、ぶつかりを小さくする

## 型と関数の口

### `Features/Import/PhotoImporter.swift`（新規。画面を持たない）

```swift
/// 取り込みの結果。仕分けの上の 1 行と、0 枚のときのアラートに使う。
struct PhotoImportResult: Equatable {
    /// 仕分け待ちに入れた記録の id（取り込んだ写真だけを仕分けるため）
    var importedIDs: [UUID] = []
    /// 食事でないとして入れなかった枚数
    var excludedCount = 0
    /// データを受け取れなかった・画像として読めなかった枚数（要判断 4）
    var failedCount = 0
}

/// 1 枚ぶんの、裏で作ったもの。
nonisolated struct PreparedPhoto: Sendable {
    let image: CGImage        // 長辺 2000px に縮め、向きを直したもの
    let takenAt: Date?        // EXIF の撮影日時。無ければ nil（要判断 6）
}

enum PhotoImporter {
    static let maxSelectionCount = 30

    /// 画像データから、縮めた画像と撮影日時を作る。メインスレッドの外で動く。読めなければ nil。
    @concurrent nonisolated static func prepare(_ data: Data) async -> PreparedPhoto?

    /// EXIF の撮影日時（と時差）を `Date` にする。テストのために分けて出す。
    nonisolated static func takenAt(fromImageProperties properties: [CFString: Any], timeZone: TimeZone = .current) -> Date?
}
```

取り込みの流れ（`@MainActor` の関数 `PhotoImportRunner.run`。同じファイルに置く）：

```swift
/// 選ばれた項目を 1 枚ずつ取り込む。進み具合は `onProgress(済んだ枚数, 全体)` で知らせる。
/// テストのために、データの受け取り・準備・判定・保存をクロージャで差し替えられるようにする。
@MainActor struct PhotoImportRunner {
    var loadData: (PhotosPickerItem) async throws -> Data?          // 本物は item.loadTransferable(type: Data.self)
    var prepare: (Data) async -> PreparedPhoto?                    // 本物は PhotoImporter.prepare
    var labels: (CGImage) async throws -> [ImageLabel]             // 本物は ImageLabeler.labels(of:)
    var save: (UIImage, Date) throws -> UUID                       // 本物は store.add(image:takenAt:).id

    func run(_ items: [PhotosPickerItem], now: () -> Date = { .now },
             onProgress: (Int, Int) -> Void) async -> PhotoImportResult
}
```

1 枚ごと：

1. `loadData` → `nil` か throw なら `failedCount += 1`（ログは種類だけ。ファイルの場所を出さない）
2. `prepare` → `nil` なら `failedCount += 1`
3. `labels` → throw したら食事扱い（要判断 7）。返れば `FoodPhotoFilter.isFood(labels)` が false なら `excludedCount += 1` で次へ
4. `save(UIImage(cgImage:), takenAt ?? now())` → id を `importedIDs` に足す。throw したら `failedCount += 1`
5. `onProgress(済んだ枚数, items.count)`

- `PhotosPickerItem` を直接テストでは作りにくいので、テストでは `run` をジェネリックにする（`[Item]` と `loadData: (Item) async throws -> Data?`）。本物は `Item == PhotosPickerItem`
- 保存は `RecordStore.add(image:takenAt:)` をそのまま使う（`RecordStore` は変えない）。`UIImage(cgImage:)` は縮めて向きを直した画像なので、`PhotoStorage.savePhotos` の描き直しでは大きさが変わらない

### `Suggestion/ImageLabeler.swift`（足す）

```swift
/// 取り込みで、ファイルに書く前の画像を判定するのに使う。
@concurrent nonisolated static func labels(of image: CGImage) async throws -> [ImageLabel]
```

- 中身は `ClassifyImageRequest().perform(on: image)` を `ImageLabel` に移すだけ（今の URL 版と同じ）

### `Suggestion/FoodPhotoFilter.swift`（新規）

```swift
/// Vision のラベルから、食事らしい写真かを決める（取り込みの除外。機能18）。
nonisolated enum FoodPhotoFilter {
    /// 要判断 8。実機で外れを見て直す
    static let threshold: Float = 0.30
    /// `food` などの大きなくくりのラベル
    static let generalLabels: Set<String> = ["food", "drink", "beverage", "dessert", "baked_goods"]
    /// 大きなくくり＋料理名（`Tag.visionLabels` を全部）
    static let foodLabels: Set<String>

    static func isFood(_ labels: [ImageLabel]) -> Bool   // どれか 1 つが threshold 以上なら true
}
```

- `Tag` はメインのアクターの型なので、`foodLabels` を作るときに `Tag.allCases.flatMap(\.visionLabels)` が使えるか（`nonisolated` から呼べるか）はビルドで確かめる。通らなければ、`Tag.visionLabels` を `nonisolated` にする

### `Features/Sort/SortView.swift`（足す）

```swift
/// 取り込んだ写真だけを出すとき。`importSummary` は上の行の下に 1 行で出す（要判断 3）。
init(importedIDs: [UUID], importSummary: PhotoImportResult)
```

- `@Query` は今の「仕分け待ち・新しい順」のまま取り、`body` で `Set(importedIDs)` に入るものだけに絞る（`#Predicate` の中で配列の `contains` を使うと、SwiftData で実行時に失敗する例があるため。`docs/data-model.md` の「言葉で探す」と同じ理由）。絞った配列を `SortCardStackView` と「あと n 枚」と `onAppear` の問い合わせに使う
  - 今 `records` を直接使っている所を、`visibleRecords`（計算プロパティ）に置き換える。`recordID` の版・入口からの版は、`visibleRecords == records` のまま
- 取り込みの版は、残りの枚数と後ろのカードを出す（入口からの版と同じ）。抜けると・最後の 1 枚を仕分けるとホームに戻る。残った写真は仕分け待ちに残る（入口から続きを仕分けられる）
- 件数の行：`Text(verbatim:)` で「取り込み \(n) 枚 ／ 除外 \(m) 枚」（`k > 0` なら「／ 読めなかった \(k) 枚」を足す）。`Theme.font(.caption)`・`Theme.textSecondary`。読み上げはそのままの文

### `Features/Home/HomeView.swift`（足す）

- **main の版（#100 マージ後）が前提**。`settingsButtonRow` は `TitleLogoView()`・`Spacer()`・設定のボタン（`Image(systemName: "gearshape")`・`.font(Theme.font(.title3))`・`.foregroundStyle(Theme.textSecondary)`・44pt 四方・`.buttonStyle(.plain)`）の `HStack`。今日の一枚の見出しは `todayHeading`、写真の大きさは `Theme.todayPhotoWidthRatio`、中身の縦の並びは `VStack(spacing: 0)` で仕分け待ちの吹き出しに `.padding(.bottom, 16)`。どれもこの Issue では変えない
- 入口（要判断 1 の A）：`settingsButtonRow` の `Spacer()` と設定のボタンの間に `PhotosPicker(selection: $pickedItems, maxSelectionCount: PhotoImporter.maxSelectionCount, matching: .images, preferredItemEncoding: .current) { Image(systemName: "photo.on.rectangle") … }`。見た目は設定のボタンと同じ修飾子（`.title3`・`textSecondary`・44pt 四方・`contentShape(.rect)`・`.buttonStyle(.plain)`）。同じ修飾子を 2 回書かないよう、小さな `private func headerIcon(_ systemName: String) -> some View` にまとめる。`accessibilityLabel("アルバムから取り込む")`
- `.onChange(of: pickedItems)`：空でなければ取り込みを始める（`Task`）。始めたらすぐ `pickedItems = []` に戻す（同じ写真をもう一度選べるように）
- 取り込み中：`@State private var importProgress: (done: Int, total: Int)?`。`nil` でなければ、ホーム全体に幕（`Theme.background.opacity(0.85)`）＋ `ProgressView` ＋「取り込み中 \(done) / \(total)」を重ね、下は触れないようにする（要判断 2 の A）
- 終わったら：`importedIDs` が 1 枚以上なら `@State private var importResult: PhotoImportResult?` に入れ、`fullScreenCover(item:)` で `SortView(importedIDs:importSummary:)` を出す（今の `isSortShown` の cover とは別に持つ）。0 枚ならアラート（要判断 5）
  - `fullScreenCover(item:)` には `Identifiable` が要るので、`PhotoImportResult` に `let id = UUID()` を足すか、包む型を作る
- 取り込み中に別のタブへ移る・アプリを閉じる：取り込みの `Task` は続く。途中で閉じた場合は、そこまでの写真が仕分け待ちに残る（ホームの入口から仕分けられる）。特別な処理はしない
- 取り込みの処理本体（`PhotoImportRunner` を組み立てて `run` を呼ぶ）は、ホームのビューに長く書かず、`PhotoImportRunner.live(store:)` のような作り方を `PhotoImporter.swift` に置いて呼ぶだけにする

## ステップ

実装担当は上から順に進める。**フェーズ A だけで「複数選択・撮影日時・仕分けへ」が動く**（Issue のメモの「時間が足りなければ除外の判定を後回し」に合わせた順）。フェーズ A の最後で一度ビルド・テスト・シミュレータ確認をしてコミットする。

### フェーズ A：複数選択・撮影日時・仕分けへ

1. `Kouiunodeiindayo/Features/Import/PhotoImporter.swift`（新規）— `PhotoImportResult`・`PreparedPhoto`・`PhotoImporter.prepare`・`takenAt(fromImageProperties:)`・`PhotoImportRunner`（この時点では `labels` を渡さない＝全部取り込む版でよい。フェーズ B で判定を足す）
   - 確認：ビルドが通る
2. `KouiunodeiindayoTests/PhotoImporterTests.swift`（新規）
   - `takenAt`：`DateTimeOriginal` だけ（`TimeZone(identifier: "Asia/Tokyo")` を渡して、期待の `Date` と一致）／時差つき（`"+09:00"` と `"-05:00"` で結果が変わる）／キーが無い・形が崩れている（`"2026-09-26 12:00"`）→ `nil`
   - `prepare`：`CGImageDestination` で EXIF（`DateTimeOriginal`）入りの 4000×3000 の JPEG を作って渡し、長辺が 2000 になること・撮影日時が読めること。向き（`kCGImagePropertyOrientation` = 6、右 90°）を付けた画像で、縮めたあと縦長（幅 < 高さ）になること。壊れたデータ → `nil`
   - `PhotoImportRunner.run`（差し替えたクロージャで）：3 枚のうち 1 枚の受け取りが失敗 → 取り込み 2・読めなかった 1／撮影日時が `nil` の写真は `now()` の値で保存される／`onProgress` が 1/3・2/3・3/3 で呼ばれる
   - 確認：`docs/rules/verification.md` の 2（テスト）が全部通る
3. `Kouiunodeiindayo/Features/Sort/SortView.swift` — `init(importedIDs:importSummary:)` と `visibleRecords`・件数の 1 行（要判断 3）。プレビュー「取り込みから（2 枚・除外 1 枚）」を足す（`SortPreviewData.makeManyUnsortedContainer()` の 3 件のうち 2 件の id を渡す。id を取る小さな関数を `SortPreviewData` に足す）。もう 1 つ「取り込みから・読めなかったあり」
   - 確認：プレビューで、取り込んだ 2 枚だけが出て「あと 2 枚」、上に件数の 1 行。既存のプレビュー（1枚・複数枚・カメラから・提案あり）が変わっていない。スクショを `.verification/102/preview-SortView-import.png` に
4. `Kouiunodeiindayo/Features/Home/HomeView.swift`（**main に合わせ直したあとの版**を直す）— 入口・取り込み中の幕・仕分けを開く・0 枚のアラート。プレビュー「取り込み中」を見られるよう、`importProgress` の初期値を渡せる `init`（プレビュー専用の引数。`SortView` の `dragOffset` と同じやり方）
   - 確認：プレビュー「今日の一枚あり・仕分け待ちあり」「SE 相当・文字サイズ XXX Large」で入口のアイコンがロゴ・設定と重ならない。「取り込み中」のプレビュー。スクショを `.verification/102/preview-HomeView-entry.png`・`preview-HomeView-importing.png`
5. `docs/data-model.md` — `takenAt` の行を「撮影日時。撮ったときに自動で付く（機能2）。アルバムから取り込んだ写真（機能18）は、写真に入っている撮影日時。入っていなければ取り込んだ時刻（要判断 6 の答え）。あとから直せる（機能13）」に直す
6. シミュレータで通しの確認（下の「シミュレータでの確認」の 1〜4）→ コミット `feat: ホームからアルバムの写真をまとめて取り込み、撮影日時で仕分け待ちに入れる (#102)`

### フェーズ B：食事でない写真を除く

7. `Kouiunodeiindayo/Suggestion/ImageLabeler.swift` — `labels(of: CGImage)` を足す
8. `Kouiunodeiindayo/Suggestion/FoodPhotoFilter.swift`（新規）— 上の口のとおり
9. `KouiunodeiindayoTests/FoodPhotoFilterTests.swift`（新規）— `server/scripts/real-labels.tsv` の 6 枚（唐揚げ・うどん・天ぷら・親子丼・味噌汁・弁当）のラベルを上位 10 個ほど写して、全部 `true`／机とキーボード（`desk 0.6`・`keyboard 0.45`・`computer 0.2`）で `false`／コーヒー（`coffee 0.8`・`cup 0.3`）で `true`／`food 0.29` だけで `false`・`food 0.30` で `true`（しきい値の境目）
10. `PhotoImporter.swift` — `PhotoImportRunner` に判定を入れる（1 枚ごとの 3）。`run` のテストに「食事でない 1 枚 → 除外 1」「Vision が throw → 取り込む（要判断 7）」を足す
11. シミュレータで通しの確認（下の 5）→ コミット `feat: 取り込みで食事らしくない写真を Vision で除く (#102)`

### フェーズ C：ドキュメントと検証の記録

12. `docs/architecture.md` — フォルダ構成に `Features/Import/PhotoImporter.swift`（アルバムからの取り込み。受け取り・縮小・撮影日時・食事の判定・保存を 1 枚ずつ）と `Suggestion/FoodPhotoFilter.swift` を足す。`Features/Sort/SortView.swift` の説明に「`importedIDs` を渡すと、取り込んだ写真だけを出す」を足す。画面のつながりの段落に「アルバムからの取り込みは、ホームの入口から `PhotosPicker` で選び、取り込み後にホームが `fullScreenCover` で `SortView(importedIDs:)` を出す」。「提案（機能26）の流れ」の「問い合わせを始めるのは2か所」は変わらない（取り込みからは頼まない理由を 1 行足す）
13. `.verification/102/notes.md` — 写真ごとの操作と見るところ、実機の確認の表（下）、測った時間とメモリ
14. PR の本文に、`docs/requirements.md` 機能18 と `docs/screen-design.md` の直し案（下の「ドキュメント」）を書く。**この 2 つのファイルは編集しない**（こうせいが直す）
15. コミット `docs: 写真の取り込みの計画と構成を実装に合わせて直す (#102)`

## シミュレータでの確認（実装担当が行う）

写真は `xcrun simctl addmedia booted <ファイル>` でシミュレータのアルバムに入れる。用意するもの（`.verification/102/media/` に置き、git には入れない）：

- 撮影日時入りの料理の写真 3 枚（縦 2・**横 1**）。無料素材なら、`exiftool` が無くても `sips` では EXIF を書けないので、テストの `CGImageDestination` と同じやり方で撮影日時（例 `2026:09:20 12:30:00`）を入れた JPEG を作る小さな Swift スクリプトを `.verification/102/` に置く
- 撮影日時の無い画像 1 枚（スクショ）
- 食事でない写真 1 枚（机やキーボード）

| # | 操作 | 見るところ | スクショ |
|---|---|---|---|
| 1 | ホームで入口を押し、料理 3 枚とスクショ 1 枚を選ぶ | 取り込み中の幕と「取り込み中 n / 4」が出て、終わると仕分けが開く。「あと 4 枚」 | `01-取り込み中.png`・`02-仕分け-取り込み4枚.png` |
| 2 | そのまま全部仕分ける | ホームに戻る。料理の 3 枚は、今日の一枚ではなく最近の写真・一覧に 9/20 の日付で入る。スクショは今日の日付 | `03-ホーム-撮影日時.png`・`04-一覧-撮影日時.png` |
| 3 | 横向きの写真を、仕分け・ホーム・一覧・詳細で出す | 仕分けは 3:4 の枠に余白つき、ホーム・一覧は四角く切り抜き、詳細は全体を縮める（今の作りのまま）。**こうせいが見て直す所を決める**（Issue の完成の条件） | `05-横-仕分け.png`〜`08-横-詳細.png` |
| 4 | 1 枚だけ選ぶ | 1 枚でも同じように仕分けが開く | — |
| 5（フェーズ B） | 料理 3 枚と机 1 枚を選ぶ | 「取り込み 3 枚 ／ 除外 1 枚」。机は仕分けにも仕分け待ちにも出ない。Vision がシミュレータで失敗するときは全部取り込まれる（要判断 7）ので、判定は実機で見る | `09-仕分け-除外1枚.png` |

- 通信を切った確認はシミュレータでは難しいので、実機で行う
- 30 枚の時間はシミュレータでは参考にならない。実機で測る

## 実機での確認（こうせいが行う。`.verification/102/notes.md` にも同じ表）

| 操作 | 見るところ |
|---|---|
| iPhone で撮ったご飯の写真を 5 枚ほど取り込む | 記録の日付が撮った日になっている（**最初にこれを見る**。ずれていたら `PHPickerMetadataOptions` の件。「調べたこと」の注意） |
| 料理・飲み物・デザート・料理でない写真（人・風景・スクショ）を混ぜて 10 枚 | 除外の外れ（料理なのに除外・料理でないのに取り込み）の数。多ければしきい値を下げるか、Jev に聞く形（#86「Jev の使いどころ」）を別 Issue に |
| 30 枚を選ぶ | 何秒かかるか（Xcode のコンソールの「取り込み: n 枚 m 秒」のログ）。途中で固まらない・落ちない。Xcode の Debug navigator のメモリが 300MB を超えない |
| 取り込み後の仕分けで、提案の点線とチップが出る | #83 の実機確認もここで一緒に行う（#86 の引き継ぎ） |
| 機内モードで取り込む | 端末にある写真は取り込め、仕分けもできる（提案が出ないだけ）。iCloud にしか無い写真は「読めなかった」に数えられる |
| 横向きの写真で、仕分け・ホーム・一覧・詳細 | 直す所をこうせいが決める |

## ドキュメント（PR の本文に書く直し案。編集はこうせい）

- `docs/requirements.md` の機能18：「他で撮った写真や、過去のご飯を入れられる。ホームから最大 30 枚まとめて選べる。食事でない写真は自動で除く。日付は写真の撮影日時（入っていなければ取り込んだ日）」。優先度を「デモまで」に
- `docs/screen-design.md`
  - 画面のつながりに「ホーム｜アルバムから取り込む（機能18）｜取り込んだ写真だけの仕分け」と「取り込んだ写真だけの仕分け｜最後の 1 枚を仕分ける／抜ける｜ホーム」
  - ホームの必要な要素に「アルバムから取り込む入口（機能18）。複数選べる（最大 30 枚）」、状態に「取り込み中（何枚目か）」
  - 仕分けの「出す写真と順番」に「アルバムから取り込んだとき：取り込んだ写真だけ。上に取り込んだ枚数と除いた枚数を出す」、状態に「アルバムから取り込んだとき」
  - カメラの行「アルバムから写真を選ぶ（機能18。カメラを自作したときに置く）」はホームの入口に置き換わるので消すか、要判断 9 の答えに合わせる
- `docs/data-model.md`：この PR で直す（ステップ 5）

## 時間が足りないときに削る順（締め切り 9/27 13:00）

上から削る。フェーズ A（複数選択・撮影日時・仕分けへ・件数の行の「取り込み n 枚」）は削らない。

1. 「読めなかった k 枚」の表示（要判断 4）→ ログだけにする
2. 取り込み中の「n / 全体」→ 回るマークだけ（要判断 2 の B）
3. 0 枚のときのアラート → 仕分けの空の画面で代える（要判断 5 の B）
4. `FoodPhotoFilterTests`・`run` のテストの判定の分 → 実機で見るだけにする（判定そのものは残す）
5. **フェーズ B 全部**（除外の判定）→ 全部取り込み、件数の行は「取り込み n 枚」だけ。Issue のメモの指示どおり
6. 撮影日時（EXIF）→ 取り込んだ時刻にする。実機で撮影日時が取れなかったときも、ここに落とす（`data-model.md` は直さない）

## リスク

- **ピッカーから来るデータに撮影日時が残っていない**（`PHPickerMetadataOptions` の既定）。実機で最初に確かめる。だめなら「調べたこと」の手順、それでもだめなら削る順の 6
- **iCloud にしか無い写真**は、受け取りで取りに行って遅い（1 枚数秒）・通信できないと失敗する。失敗は「読めなかった」に数えて先に進む。遅さが目立つときは、受け取りだけ 2 枚ずつ先に始める（`TaskGroup` で次の 1 枚を先読み）。メモリは 1 枚あたり元データ分しか増えない
- **Vision がシミュレータで失敗する**（#82 のリスクと同じ）。失敗は食事扱いなので、シミュレータでは全部取り込まれる。除外の確認は実機とテストで行う
- **保存がメインスレッドで重い**（1 枚 0.05〜0.1 秒）。30 枚連続でも 1 枚ごとに進み具合の描き直しが入るので固まって見えないはず。カクつくなら、保存の前後に `await Task.yield()` を入れる。`PhotoStorage` を裏に移すのはこの Issue ではやらない（書き込みの入口を変えるため）
- **取り込み中に提案の問い合わせが混む**：取り込みからは頼まず、仕分けを開いたときに並び順に頼む（前提・確認事項）。30 枚だと最後の写真の提案まで 30〜45 秒かかるが、先頭から埋まるので仕分けは止まらない
- **`SortView` の絞り込みを `#Predicate` に書くと実行時に落ちる**ことがある。Swift 側で絞る（口の説明のとおり）
- **`Tag.visionLabels` を `nonisolated` の場所から読めない**（既定のアクターがメイン）。ビルドで分かる。`FoodPhotoFilter` を `@MainActor` で呼ぶ（判定は軽いので、ラベルを受け取ったあとメインで判定してよい）か、`visionLabels` を `nonisolated` にする
- **#103（おまかせ）が `SortView` を同時に触る**。先にマージされたほうに合わせる。この Issue の `SortView` の変更は、`init` 1 つ・`visibleRecords`・件数の 1 行に留める
- **`project.pbxproj` の未コミットの変更**が作業ツリーに残っている（#86 の引き継ぎ。Xcode の書き戻し）。コミットに混ぜない。`git add` はファイルを指定する

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）・2（テスト。`PhotoImporterTests`・`FoodPhotoFilterTests` と既存のテストが全部通る）
- プレビュー：`SortView` の取り込みの 2 つ、`HomeView` の入口と取り込み中。既存のプレビューが崩れていない
- シミュレータ：上の「シミュレータでの確認」の表。スクショを `.verification/102/` に
- 実機（こうせい）：上の「実機での確認」の表。Issue の完成の条件のうち「撮影日時」「除外」「通信できなくても」「横向きのスクショ確認」はここで見る。**実機確認が済むまで、PR の「実機での確認」は「未」で出す**
- `git status` で `project.pbxproj` と `Config/Local.xcconfig` がコミットに入っていない
