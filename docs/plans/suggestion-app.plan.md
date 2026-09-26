# 実装計画: 撮った写真のラベルを Vision で取り、Worker に提案を問い合わせて保存する

## 概要

`Kouiunodeiindayo/Suggestion/` の4ファイル（`ImageLabeler`・`SuggestionClient`・`SuggestionService`・`SuggestionMock`）を作り、撮った直後と仕分けの画面を開いたときに、裏で Vision → Worker に問い合わせて、結果を `RecordStore.saveSuggestion` で保存する。画面に提案を出すのは #83（この Issue では出さない）。対応する Issue：#82（親 #86）。対応する機能：`docs/requirements.md` の機能26（ジャンルとタグの提案）のアプリ側の処理。

流れは `docs/architecture.md`「提案（機能26）の流れ」、受け渡しの形（送る JSON・返る JSON・合言葉・時間切れ・失敗の扱い）は `docs/suggestion-api.md`、保存の決まりは `docs/architecture.md`「書くとき」の「提案を保存する」（#81 で実装済み）が正。この計画はそれを型と関数に落としたもの。表の中身は繰り返さない。

## 前提・確認事項

- #79（受け渡しの形）・#80（Worker。本番にデプロイ済み）・#81（`Tag`・`Record` の提案の項目・`RecordStore.saveSuggestion`）は main に入っている
- `project.pbxproj` は触らない。`Suggestion/` は同期フォルダ（`Kouiunodeiindayo/`）の中なので、置くだけで Xcode が認識する
- ビルド設定の既定は `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`・`SWIFT_APPROACHABLE_CONCURRENCY = YES`（何も書かない型と関数はメインスレッドで動く。`nonisolated` の `async` 関数も、呼んだ側のスレッドで動く）。**メインスレッドの外で動かしたい処理には `@concurrent` を付ける**（Vision の実行と JSON の組み立て）
- `saveSuggestion` はメインスレッドで呼ぶ。`id` で記録を取り直し、「消えていた・仕分け済み・問い合わせ済み」なら何も書かない（#81 で実装済み）。この Issue では `RecordStore` を変えない
- Worker の時間切れは 1.2 秒（`server/src/jev.ts`）。アプリの 1.5 秒より先に 502 で返る作り（`docs/plans/suggestion-worker.plan.md`）

### Vision（公式ドキュメントで確認済み）

- `ClassifyImageRequest`（iOS 18 以降の Swift 向けの新しい API。iOS 26 以上が対象なので `#available` は要らない）
  - `let results = try await ClassifyImageRequest().perform(on: url)` で `[ClassificationObservation]` が返る。画像は URL・`Data`・`CGImage` などで渡せる（`perform(on:orientation:)`）
  - `ClassificationObservation.identifier: String`（英語のラベル名。例 `ramen`）、`confidence: Float`（0〜1）
  - **分類の一覧（1000 以上）が全部返る**。確信度の高い順に並んでいる保証は書かれていないので、自分で並べ替える
- 写真は `PhotoStorage` が保存した JPEG（長辺 2000px、`UIGraphicsImageRenderer` で描き直しているので向きは常に「上」）を、ファイルの URL のまま渡す。`UIImage` を裏のスレッドに渡さずに済む。向きは指定しない（既定の `.up`）

### Worker の URL と合言葉を Info.plist に入れる方法（公式ドキュメントで確認済み）

- `INFOPLIST_KEY_〜` のビルド設定は、Apple が決めたキー（`NSCameraUsageDescription` など）にしか効かない。独自のキーは入れられない
- 独自のキーは、Info.plist のファイル（`INFOPLIST_FILE`）に書く。`GENERATE_INFOPLIST_FILE = YES` のままでも、ビルド時に「そのファイルの中身」と「`INFOPLIST_KEY_〜` から作った中身」がまとめられる（Build settings reference の `INFOPLIST_FILE`）
- ファイルの中の `$(名前)` は、ビルド時にビルド設定の値に置き換わる（`INFOPLIST_EXPAND_BUILD_SETTINGS`。既定で YES）。これで `Config/Local.xcconfig` に書いた値を Info.plist に入れられる
- **Info.plist のファイルを同期フォルダ（`Kouiunodeiindayo/`）の中に置くと、リソースとしてもコピーされて「Multiple commands produce … Info.plist」でビルドが失敗する**（外すには Xcode でターゲットから除外 = `project.pbxproj` の変更が要る）。同期フォルダの外（`Config/`）に置く
- アプリは `Bundle.main.object(forInfoDictionaryKey:)` で読む
- 流れ：`Config/Local.xcconfig`（値。git に入れない）→ `Config/Base.xcconfig` が `#include?` で読む → `Config/Info.plist` の `$(SUGGESTION_BASE_URL)`・`$(SUGGESTION_TOKEN)` が置き換わる → アプリの Info.plist → `Bundle.main`
- xcconfig では `//` 以降がコメントになる。URL は `https:/$()/<worker>.workers.dev` のように書く（`$()` は空の値で、`//` を分けるため）

### 決めたこと（2026-09-26 こうせい確認。計画のときの案は全部おすすめのほうに決めた）

1. **Info.plist への取り込みは、`Config/Info.plist` と `Config/Base.xcconfig` で行う。** `Config/Info.plist` に独自キー2つを書き、`Base.xcconfig` に `INFOPLIST_FILE = Config/Info.plist` を1行足す。どちらもテキストのファイルで、`project.pbxproj` は変わらない（今も `Base.xcconfig` で `INFOPLIST_KEY_〜` を設定している流儀と同じ）。人の作業は、自分の `Local.xcconfig` に値を書くことと、Xcode で設定が効いているかを見ることだけ（下の「人が Xcode で行う作業」）。ターゲットの Info タブで足す案は、`project.pbxproj` に値と同期フォルダの除外が書かれ、手元ごとにずれやすいので採らない
2. **URL か合言葉が未設定なら、問い合わせない。** Vision も動かさず、何も保存しない（`suggestedAt` は `nil` のまま）。起動後に1回だけログに出す。撮る・仕分けるは変わらない。ビルドは失敗させない（相方がビルドできなくなるため）
3. **`@Environment` の既定値は、何もしないモック（`SuggestionMock.disabled`）。** 本物はアプリの入口（`KouiunodeiindayoApp`）で明示して渡す。既存のプレビューが勝手に本物の Worker を呼び、クレジットを使わないようにするため（プレビューのビルドにも Info.plist の値は入る）
4. **同じ写真は重ねて問い合わせず、受け付けた順に1件ずつ行う。** 撮った直後は `CameraFlowView` の「追加」のあとと、すぐ開く `SortView(recordID:)` の両方から同じ写真が来る。仕分け待ちが溜まっていると、開いた瞬間に何十枚も来る。本物の Service が「問い合わせ中・待ちの `id`」を控えて同じ `id` を弾き、1件ずつ処理する（Vision を何十枚も同時に動かさない・Worker に同時に投げない）。仕分けの画面は新しい順に頼むので、画面に先に出る写真から埋まる
5. **Vision のラベルが（名前の形で絞ったあと）0個なら、Worker に送らず「提案なし」として保存する。** Vision は同じ写真には同じ結果を返すので、問い合わせ直しても変わらないため。Vision 自体が失敗した（throw）ときは、何も保存しない（通信の失敗と同じ扱い）
6. **プレビューでの確認は、`SuggestionMock.swift` に置く確認用の小さなビューで行う。** 仕分け待ちの記録ごとに `suggestedGenre`・`suggestedTags` を文字で並べるだけ。開くとモックが `saveSuggestion` を呼び、「未問い合わせ」から提案に変わる。#83 の画面ができたら、#83 のプレビューで同じモックを使う

### 実装しながら変えたこと（2026-09-26）

- 名前：何もしないモックは `SuggestionMock.none` ではなく `SuggestionMock.disabled`、提案なしの結果は `SuggestionResult.none` ではなく `SuggestionResult.empty` にした。`Optional` の型のところで `.none` と書くと「値が無い（nil）」と読まれ、黙って意味が変わるため（`Genre.noGenre` と同じ理由）
- `SuggestionMock` に `immediate`（待たずに、その場で保存する版）を足した。プレビューの静止画は開いた直後に撮られ、裏で保存するのを待たないので、確認用のプレビューではこれを使う
- テストは `SuggestionClientTests` に加えて `SuggestionServiceTests` を足した（モックが保存すること・何もしないモック・URL と合言葉が未設定の本物が保存しないこと）。Vision と Worker を呼ぶ流れは実機で見る
- レビュー（2026-09-26）を受けて直した点
  - Vision の失敗のログに、エラーの説明文（写真のファイルの場所が入りうる）を出さず、種類とコードだけを出す（通信の失敗と同じ `describe`）
  - `LiveSuggestionService` は `PhotoStorage` を持たない。写真の場所は、頼まれた時点で `store`（`RecordStore.photoURL(fileName:)`）から作って待ち行列に入れる。保存した置き場所と読む置き場所がずれないように
  - `LiveSuggestionService` に、ラベルの取得と問い合わせをクロージャで差し替える `init(labels:suggest:)` を足した（本物は `init(configuration:)`）。`SuggestionServiceTests` に、同じ写真を弾く・1件ずつ処理する・失敗したら次に頼めば問い合わせ直す・写真の場所は頼んだ `RecordStore` から作る、のテストを足した（Vision もネットも呼ばない）
  - URL は https だけを許す。http は手元の `wrangler dev`（`localhost`）を呼ぶときだけ（合言葉を平文で流さないため）
- `Config/Base.xcconfig` はプロジェクト全体に割り当てているので、`INFOPLIST_FILE` はテストのターゲットにも効く（テストの束の Info.plist にも2つのキーが入る）。テストの束はアプリに入らないので、そのままにした

## 型と関数の口

### `Suggestion/ImageLabeler.swift`

```swift
/// Vision に渡して取れたラベル1つ。Worker に送る形（名前の形の絞り込み・丸め）はまだかけていない。
struct ImageLabel: Equatable, Sendable {
    let name: String
    let confidence: Float
}

/// 写真から Vision のラベルを取る（端末の中だけ）。
enum ImageLabeler {
    /// メインスレッドの外で動く。写真ファイルの URL を受け取る（`UIImage` を渡さない）。
    @concurrent static func labels(ofPhotoAt url: URL) async throws -> [ImageLabel]
}
```

- 中身は `ClassifyImageRequest().perform(on: url)` を `ImageLabel` に移すだけ。並べ替え・絞り込みは下の `SuggestionRequest` でやる（Vision を呼ばずにテストできるように）

### `Suggestion/SuggestionClient.swift`

```swift
/// `/suggest` に送る JSON（`docs/suggestion-api.md`）。
struct SuggestionRequest: Encodable, Equatable {
    struct Label: Encodable, Equatable { let name: String; let confidence: Double }
    let labels: [Label]

    /// Vision のラベルを送る形に整える。名前の形（英小文字・数字・`_`、1〜64 文字）に合うものだけを、
    /// 確信度の高い順に最大 20 個、確信度は小数第2位に丸める。確信度が同じなら名前の順（結果を毎回同じにするため）。
    /// 1個も残らなければ `nil`。
    init?(labels: [ImageLabel])
}

/// `/suggest` から返る JSON。知らないジャンル・タグのキーは捨てる（落とさない）。
struct SuggestionResult: Equatable, Sendable {
    let genre: Genre?
    let tags: [Tag]
    static let empty = SuggestionResult(genre: nil, tags: [])
}

/// Worker への通信。URL と合言葉は Info.plist（元は `Config/Local.xcconfig`）から読む。
struct SuggestionClient {
    struct Configuration: Equatable { let baseURL: URL; let token: String }

    /// Info.plist から読む。どちらかが空・`$(…)` のまま・URL として読めないときは `nil`（決めたこと 2）。
    static func configurationFromBundle(_ bundle: Bundle = .main) -> Configuration?

    init(configuration: Configuration, session: URLSession = .suggestion)

    /// `POST /suggest`。200 以外・時間切れ・通信できない・JSON が読めない、はどれも throw する。
    func suggest(_ request: SuggestionRequest) async throws -> SuggestionResult

    /// テストのために、組み立てと読み取りを分けて外に出す（ネットは呼ばない）。
    static func makeURLRequest(_ request: SuggestionRequest, configuration: Configuration) throws -> URLRequest
    static func decodeResult(from data: Data) throws -> SuggestionResult
}
```

- 時間切れ 1.5 秒は、`URLSessionConfiguration.ephemeral` の `timeoutIntervalForRequest`・`timeoutIntervalForResource` の両方に 1.5 を入れた専用の `URLSession`（`URLSession.suggestion`）で守る。`URLRequest.timeoutInterval` だけだと「無通信の時間」で、全体の時間ではないため。`ephemeral` はキャッシュ・Cookie を端末に残さないため
- ヘッダーは `Content-Type: application/json` と `Authorization: Bearer <合言葉>`
- 返る JSON は、いったん `genre: String?`・`tags: [String]` で読み、`Genre(rawValue:)` が `Genre.suggestable` に入るものだけ・`Tag(rawValue:)` で読めるものだけを残す
- ログ：失敗は HTTP の状態コードかエラーの種類だけを出す。**URL・合言葉・送ったラベルは出さない**

### `Suggestion/SuggestionService.swift`

```swift
/// 提案の問い合わせのまとめ役。画面は `@Environment(\.suggestionService)` で受け取り、これだけを呼ぶ。
/// メインスレッドで呼ぶ。問い合わせは裏で行い、結果はメインスレッドで `store.saveSuggestion` に渡す。
protocol SuggestionService {
    /// 写真1枚の提案を問い合わせる。すぐ戻る（結果を待たない）。
    /// `Record` ではなく `id` と `photoFileName` を受け取る（`@Model` はスレッドをまたげない）。
    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore)
}

/// 本物。ImageLabeler → SuggestionClient。
@MainActor final class LiveSuggestionService: SuggestionService {
    convenience init(configuration: SuggestionClient.Configuration? = SuggestionClient.configurationFromBundle())
    init(labels: @escaping LabelProvider, suggest: Suggester?)   // テストで差し替える
}

extension EnvironmentValues {
    @Entry var suggestionService: any SuggestionService = SuggestionMock.disabled  // 決めたこと 3
}
```

`LiveSuggestionService.requestSuggestion` の中：

1. 設定が `nil` なら何もしない（最初の1回だけログ。決めたこと 2）
2. 問い合わせ中・待ち行列にある `id` なら何もしない（決めたこと 4）
3. 待ち行列に `(id, photoFileName, store)` を足す。処理中でなければ、1件ずつ取り出す `Task` を始める（`Task` はメインスレッドのもの。重い処理は `@concurrent` の関数の中）
4. 1件の処理：
   1. `photoStorage` から写真の URL を得る（`PhotoStorage` に `photoURL(fileName:)` を足す。画面や Service でファイルの場所を組み立てないため）
   2. `ImageLabeler.labels(ofPhotoAt:)`。throw したら何も保存しない（ログ）
   3. `SuggestionRequest(labels:)` が `nil` なら `store.saveSuggestion(genre: nil, tags: [], for: id)`（決めたこと 5）
   4. `SuggestionClient.suggest`。throw したら何も保存しない（ログ。`suggestedAt` は `nil` のまま）
   5. 成功したら `store.saveSuggestion(genre: result.genre, tags: result.tags, for: id)`。提案なし（`genre == nil`・`tags` が空）もそのまま渡す（問い合わせ済みにする）
- `store`（`RecordStore`）はメインスレッドの `ModelContext` を持つ struct。メインスレッドの `Task` の中だけで使うので、裏のスレッドには渡らない
- 「仕分け済みなら書かない」「問い合わせ済みなら書かない」は `saveSuggestion` 側が守るので、Service では見ない

### `Suggestion/SuggestionMock.swift`

```swift
/// 通信せずに、決まった提案を返すモック。プレビューで使う。
struct SuggestionMock: SuggestionService {
    let result: SuggestionResult?   // nil は「何もしない」（失敗・未設定と同じ）
    var delay: Duration = .milliseconds(300)   // 出てくる様子を見るため

    static let disabled = SuggestionMock(result: nil)
    static let ramen = SuggestionMock(result: SuggestionResult(genre: .food, tags: [.ramen, .noodles, .chinese]))
    static let noSuggestion = SuggestionMock(result: .empty)   // 提案なし（200）
}
```

- `requestSuggestion` は `delay` のあとメインスレッドで `store.saveSuggestion` を呼ぶだけ
- 確認用のビューとプレビュー（決めたこと 6）もここに置く

## 問い合わせを始める2か所

- `Features/Camera/CameraFlowView.swift` の `save(_:)`：`RecordStore.add` が成功したあと、`step = .sort(...)` の前に
  ```swift
  suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
  ```
  （`@Environment(\.suggestionService) private var suggestionService` を足す。`store` はその場で作った `RecordStore` を変数に取り出して使い回す）
- `Features/Sort/SortView.swift`：開いたとき（`.onAppear` の中、`wasEmptyAtOpen` を控える処理の隣）に、`records` のうち `suggestedAt == nil` のものを並び順（新しい順）で頼む
  ```swift
  for record in records where record.suggestedAt == nil {
      suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
  }
  ```
  - `@Query` の条件は変えない（すでに仕分け待ちだけ）。撮った直後の1枚だけのとき（`recordID` あり）も同じ書き方でよい（同じ `id` は Service が弾く）
  - `SortView` は #83 でも触る。ここで足すのは `.onAppear` の数行と `@Environment` の1行だけにして、ぶつかりを小さくする
- `App/KouiunodeiindayoApp.swift`：`RootView` を包む `LaunchSplashView` に `.environment(\.suggestionService, suggestionService)` を付ける。本物は `@State private var suggestionService = LiveSuggestionService()` で1つだけ作る（問い合わせ中の控えをアプリ全体で1つにするため）
  - `LiveSuggestionService` は `@Observable` にしない（画面が変化を見る必要が無い）。`@State` に入れるのは、`App` の作り直しで作り直されないようにするため

## ステップ

1. `Config/Info.plist`（新規）・`Config/Base.xcconfig` — URL と合言葉の配線（決めたこと 1）
   - `Config/Info.plist`：`SuggestionBaseURL` = `$(SUGGESTION_BASE_URL)`、`SuggestionToken` = `$(SUGGESTION_TOKEN)` の2つだけ
   - `Config/Base.xcconfig`：`INFOPLIST_FILE = Config/Info.plist` と、既定値 `SUGGESTION_BASE_URL =`・`SUGGESTION_TOKEN =`（空。`#include? "Local.xcconfig"` より前。Local が無くてもビルドが通るように）。コメントで「独自のキーは `INFOPLIST_KEY_〜` が効かないので Config/Info.plist に書く」「同期フォルダに置かない理由」を書く
   - 確認：ビルドが通る。ビルドしたアプリの Info.plist にキーが2つあり、値が空（`Local.xcconfig` を読まない AI の環境では空になる。AI は値を表示しない。キーの有無だけを `plutil -extract SuggestionBaseURL raw …` の終了コードで見る）
2. `Config/Local.xcconfig.example` — 見本を足す（偽の値だけ）
   ```
   // Worker（中継サーバー）の URL と合言葉。docs/setup.md の「7. Worker」。
   // xcconfig では // 以降がコメントになるので、URL の // は $() で区切って書く
   SUGGESTION_BASE_URL = https:/$()/your-worker.example.workers.dev
   SUGGESTION_TOKEN = replace-with-your-token
   ```
3. `docs/setup.md` — 「3. 署名の設定」の手順に URL と合言葉を書く行を足すか、「7. Worker」に「アプリから Worker を呼ぶ」の小見出しを足す（`$()` の書き方・合言葉は本番の `SUGGEST_TOKEN` と同じ値・書いたら Xcode を開き直す・未設定なら提案が出ないだけ・合言葉はアプリから抜き取れる前提（ADR 0006））
4. `Data/PhotoStorage.swift` — `func photoURL(fileName: String) -> URL` を足す（`photo(fileName:)` の中の組み立てもこれを使う）
5. `Suggestion/ImageLabeler.swift` — 上の口のとおり
6. `Suggestion/SuggestionClient.swift` — 上の口のとおり
7. `Suggestion/SuggestionService.swift` — 上の口のとおり
8. `Suggestion/SuggestionMock.swift` — 上の口のとおり ＋ 確認用のビューとプレビュー
9. `App/KouiunodeiindayoApp.swift`・`Features/Camera/CameraFlowView.swift`・`Features/Sort/SortView.swift` — 上の「問い合わせを始める2か所」
   - 既存の `CameraFlowView`・`SortView` のプレビューは、既定の `SuggestionMock.disabled` のままでよい（通信しない）
10. `KouiunodeiindayoTests/SuggestionClientTests.swift`（新規）— ネットは呼ばない
    - 送る形：`SuggestionRequest(labels:)` が、確信度の高い順・最大 20 個・小数第2位に丸める（`0.625` → `0.63` のような境目も）・名前の形に合わないもの（大文字・`-`・空白・65 文字）を捨てる・全部捨てたら `nil`・確信度が同じなら名前の順
    - JSON：`makeURLRequest` の URL（`…/suggest`）・メソッド `POST`・2つのヘッダー・本文を `JSONSerialization` で読み直して `labels[].name`・`confidence` が期待どおり
    - 返る形：`decodeResult` が `{"genre":"food","tags":["ramen","noodles"]}` を読む／`{"genre":null,"tags":[]}` を提案なしで読む／知らないジャンル（`"unsorted"`・`"soup"`）は `nil`、知らないタグは捨てる／壊れた JSON は throw
    - 設定：`configurationFromBundle` の判定は、`Bundle` ではなく辞書を受ける小さな関数に分けて、空・`$(SUGGESTION_BASE_URL)` のまま・URL として読めない、で `nil` になることを見る
11. `docs/architecture.md` — 変わる点だけ直す：フォルダ構成に `Config/Info.plist` を足す。「提案（機能26）の流れ」に「同じ写真は1件ずつ・重ねて問い合わせない」「URL と合言葉が未設定なら問い合わせない」
12. `.verification/82/` にプレビューのスクショと `notes.md`（実機の確認の手順と見るところ）

## 人が Xcode で行う作業

`project.pbxproj` は変わらない（決めたこと 1）。

1. 自分の `Config/Local.xcconfig` に2行を書く（見本は `Config/Local.xcconfig.example`）。URL は本番の Worker の URL を `https:/$()/…` の形で、合言葉は Worker に `wrangler secret put SUGGEST_TOKEN` で入れた本番の値
2. Xcode を終了（Cmd+Q）して開き直す（xcconfig の変更を読ませるため）
3. ターゲット `Kouiunodeiindayo` → Build Settings（All・Combined）で「Info.plist File」を検索し、`Config/Info.plist` が**細字**（xcconfig の値が使われている）で出ていることを見る。太字ならターゲット側に値があるので、その行を選んで Delete キーで消す
4. Product → Clean Build Folder（Shift+Cmd+K）のあと、実機でビルドする
5. `git status` で `project.pbxproj` が変わっていないことを見る（変わっていたら、その差分を AI に見せて止まる）

## 実機での確認（人が行う）

`.verification/82/notes.md` にも同じ表を書く。

| 操作 | 見るところ |
|---|---|
| Wi-Fi かモバイル通信がある状態で、ラーメンなど分かりやすい料理を撮る | 仕分けの画面がいつもどおりすぐ出る（提案を待たない）。数秒以内に、Xcode のコンソールに「提案を保存した」のログ（ジャンルとタグのキーだけ）が出る |
| 同じ写真を仕分けずに ✕ で抜け、ホームの仕分け待ちから開き直す | もう一度問い合わせていない（ログが出ない。問い合わせ済みのため） |
| 機内モードにして撮る | 撮る・仕分けるがいつもどおりできる。ログに「通信できなかった」が出て、提案は保存されない |
| 機内モードのまま仕分けずに抜け、機内モードを切ってから仕分け待ちを開く | 開いたときに問い合わせ直し、提案が保存される |
| 仕分け待ちを 5 枚以上溜めてから開く | 画面が固まらない。ログで1件ずつ順に問い合わせている |
| `Local.xcconfig` の2行を消してビルドし直す（任意） | 撮る・仕分けるはいつもどおり。問い合わせない旨のログが1回だけ出る |

- #83 がまだなので、提案は画面に出ない。保存されたかは、ログ（`Logger` の category `SuggestionService`）で見る。ログにはジャンルとタグのキーだけを出し、URL・合言葉・ラベルは出さない
- Worker が 429・502 を返すことがある（`docs/plans/suggestion-worker.plan.md` の「リスク」）。そのときは保存されないのが正しい動き。何度か撮り直して、成功する回があることを見る

## リスク

- **Worker の失敗が多いと、提案がなかなか保存されない**。Jev の提供元の混雑で 429・503 がよく返る（#80 の計測で半分前後）。アプリは「次に仕分けを開いたとき」にしか問い合わせ直さない（`docs/architecture.md` の決まり）。デモで困るようなら、アプリ側の再試行を別の Issue で相談する（この Issue では足さない）
- **Vision がシミュレータで失敗することがある**（分類のモデルを動かせず throw する例がある）。失敗しても何も保存しないだけで、撮る・仕分けるは止まらない。本当に動くかは実機で見る
- **合言葉はアプリの中（Info.plist）に平文で入り、抜き取れる**。ADR 0006 で「ハッカソンのデモの間だけの簡易的な対策」と決めている。コード・ログ・コミットには出さない。App Store に出すときは ADR 0006 のとおり別途検討
- **`Config/Info.plist` を Xcode の Info タブで編集すると**、Xcode が `INFOPLIST_FILE` をターゲット側（pbxproj）に書き戻すことがある。`Base.xcconfig` のコメントに「Info タブで独自キーを足さず、このファイルを直す」と書く
- **1.5 秒は Worker の呼び出しだけ**。Vision の時間は含めない（`docs/suggestion-api.md` の時間切れはアプリから Worker への問い合わせのもの）。Vision は実機で 0.1〜0.5 秒ほどの見込みだが、実機で測って notes.md に書く
- **撮った直後に同じ写真を2回頼む**（`CameraFlowView` と `SortView(recordID:)`）。Service が問い合わせ中の `id` を弾くので1回になる。万一2回届いても `saveSuggestion` が2回目を書かない
- **`SortView` は #83 でも大きく触る**。この Issue で足すのは数行だけにする。先にマージされたほうに合わせる
- **`ModelContext` の自動保存**：`saveSuggestion` は `save()` を呼ばない（#81 の流儀）。アプリをすぐ終了すると提案が残らないことがあるが、そのときは次に仕分けを開いたときに問い合わせ直すだけなので、変えない

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）・2（テスト。`SuggestionClientTests` と既存のテストが全部通る）
- プレビュー：`SuggestionMock.swift` の確認用のプレビューで、`SuggestionMock.ramen` のとき「食べ物・ラーメン・麺類・中華」、`noSuggestion` のとき「提案なし（問い合わせ済み）」、`disabled` のとき「未問い合わせ」のまま、になることを見る。スクショを `.verification/82/preview-SuggestionCheckView.png` などに残す
- 実機（人が行う。上の表）。Issue の完成の条件の「数秒以内に提案が保存される」「機内モードでも撮る・仕分けるができる」はここで見る
- `git status` で `project.pbxproj` と `Config/Local.xcconfig` が差分に出ていない
