# 実装計画: 一覧で、言葉で記録を探す

## 概要

一覧の上に検索の欄を置き、「前に食べたうまいラーメン」のような言葉から、タグ・うまい・撮った時期の条件を読み取って、合う記録だけを並べる。条件の読み取りは Worker の `POST /search`（Jev に選択肢から選ばせる）と、端末の中の単純な読み取り（タグの名前・「うまい」・「今日」などの言葉を探す）の 2 段。絞り込みは端末の中で行い、記録は送らない。対応する Issue：#85（親 #86）。対応する機能：`docs/requirements.md` の機能28（言葉で探す。優先度は「余裕があれば」）。

受け渡しの形は `docs/suggestion-api.md` の `POST /search`、絞り込みの決まりは `docs/data-model.md`「よく使う取り出し方」の「言葉で探す」、送ってよいもの（検索の言葉だけ）は ADR 0006 が正。

**締め切り（9/27 13:00）に対して優先度が一番低い。ブランチは `feat/85-word-search`（2026-09-27 に main から切った。#102・#103・#84 は未マージ）。まず M0 だけを作り、レビューのあとで M1・M2 に進む。** 残り時間が 2 時間を切っていたら着手しない。着手したら、下の「最小の形」から作り、時間が残った分だけ足す。

## 最小の形と、削る順（先に読む）

段階ごとに、そこで止めても動く・PR にできる形にしてある。上の段ほど先に作る。**削るときは下の段から削る。**

| 段 | 中身 | Worker | 目安 |
|---|---|---|---|
| **M0（最小。これだけは作る）** | 検索の欄、端末の中の読み取り（`LocalSearchParser`）、絞り込み（`RecordSearchFilter`）、合う記録が無いときの表示、絞り込みをやめる | 触らない・デプロイ不要 | 1〜1.5 時間 |
| M1 | 読み取った条件をチップで見せる（何で絞ったかが分かる） | 触らない | 30 分 |
| M2 | Worker の `POST /search` と、アプリからの問い合わせ（読み取れなかった言葉を Jev に任せる） | 足す・こうせいがデプロイ | 1.5〜2 時間 |

- M0 だけで、Issue の完成の条件の「言葉で絞り込める。絞り込みをやめると元の一覧に戻る」を満たす。「通信できないときは、その旨を出して一覧はそのまま」は、M0 では通信しないので当てはまらない（要判断 5）
- 時間が足りなければ、M2 → M1 の順に削る。M0 も間に合わなければ、この Issue は見送り（デモの台本で触れない）
- M2 を足すときも、M0 の端末の中の読み取りは残す（会場の Wi-Fi が不安定でもデモで絞り込めるように）

## 決めたこと（全部推奨、2026-09-27 こうせい確認）

本文の「要判断 n」は、この番号を指す。

1. **検索の欄**：ロゴと区切り線の下、仕分け待ちの入口の上に、いつも出ている 1 行の欄（虫めがね＋「ラーメン、うまい、今月 など」の薄い文字）。角丸・墨の細い線。一覧と一緒にスクロールする
2. **いつ探すか**：キーボードの「検索」（改行）を押したとき。1 文字ごとには探さない
3. **読み取った条件の見せ方（M1）**：欄のすぐ下に、読み取った条件をチップで並べる。右端に「やめる」
4. **文言**：欄の薄い文字「ラーメン、うまい、今月 など」／合う記録が無い「合う記録がありません」＋「絞り込みをやめる」／読み取れなかった「条件を読み取れませんでした。タグの名前や『うまい』『今月』で探せます」（一覧はそのまま）
5. **通信できないとき（M2）**：先に端末の中で読み取り、読み取れた条件があれば通信せずに絞る。読み取れなかったときだけ Worker に聞き、通信できなければ「通信できませんでした。タグの名前や『うまい』『今月』なら通信なしで探せます」を出して一覧はそのまま
6. **結果の並べ方**：今の一覧と同じ（新しい順・月ごとの見出し・3 列）。絞り込み中は仕分け待ちの入口を隠す
7. **「前に食べた」の読み方**：「前に」「前の」「昔」は `earlier`（今月 1 日より前）。「今日」→ `today`、「今週」→ `this_week`、「今月」→ `this_month`。「昨日」「先週」「先月」は読み取らない。「今月より前」「今月以前」も `earlier`（「今月」より先に見る。レビューで足した）。「今年」→ `this_year`（今年の 1 月 1 日以降。M1 で足した）。「より前」「以前」だけ（「昨日以前」など）は読み取らない

## 実装で計画から変えたこと（2026-09-27。M0）

- `SearchCondition`・`SearchPeriod` は `Sendable` にしていない（M0 は端末の中だけで、スレッドをまたがないため。M2 で要れば足す）
- 「うまい」の言葉は、言い切りの形ではなく頭の部分で探す（「うまい」「うまかった」「美味」「旨」「おいし」「お気に入り」）。「おいしかった」も当たるようにするため
- 欄の ✕ は、読み取れなかったときの知らせも消し、キーボードも閉じる（`clear()`）。言葉が空のまま「検索」を押したときも `clear()`
- プレビュー「検索の欄（空）」は、仕分け待ちの無いコンテナ（`HomePreviewData.makeNoUnsortedContainer()`）で見る
- （レビュー 1 周目）仕分け済みが 0 件でも、絞り込み中なら「合う記録がありません」とやめるボタンを出す（絞り込み中を先に見る）
- （レビュー 1 周目）欄を手で空にしたら、絞り込みと知らせもやめる（キーボードは閉じない）
- （レビュー 1 周目）時期で絞るときの「今」を画面に持ち、探したとき・アプリに戻ったとき・日付が変わったとき（`NSCalendarDayChanged`）に取り直す
- （レビュー 1 周目）探したあと、件数か知らせを読み上げる
- （レビュー 1・2 周目）詳細には、開いた時点の並びを渡す（絞り込みから外れてもページが飛ばないように）。並びは記録の id で持ち、渡すときに今の `@Query`（絞る前）から引き直す（詳細で消した記録を読まないように）。開く記録と並びは 1 つの値（`DetailSelection`。開いた記録も id で持つ）にまとめて sheet の `item` にし、sheet の中で今の `@Query` から開いた記録と並びを引き直す。開いた記録が消えていたら詳細を作らない（レビュー 3 周目。ホームの詳細も同じ形にした）（別々の `@State` だと、sheet の中身を作るときに並びが空のまま読まれ、詳細が 1 件だけになった。シミュレータで確認）
- （レビュー 1 周目）`docs/suggestion-api.md` の時期の表を「始まり以降」に直した（日付を未来に直した記録も今週・今月に入る）

## 前提・確認事項

- `docs/suggestion-api.md` に `POST /search` の形（送る `{ query }`・返る `{ tag, favoriteOnly, period }`・時間切れ 3 秒・エラー）は #79 で決まっている。Worker は今 `/search` を 404 で返す（`server/src/index.ts`）
- `docs/data-model.md`「言葉で探す」：`genre` が `unsorted` 以外を `@Query` で取り、タグ・うまい・時期は取ったあとに Swift 側で絞る（`tags` の配列を `#Predicate` で使うと実行時に失敗する報告があるため）。料理のタグは、大分類・系統にも当てはめる（「ラーメン」だけの記録も「麺類」「中華」で当たる）。**一覧の今の `@Query`（仕分け済み・新しい順）がそのまま使える**
- 時期の区切りは暦で、端末の中で `takenAt` に当てはめる（`suggestion-api.md` の `period` の表。週の始まりは端末の設定 ＝ `Calendar.current`）
- `Tag`・`Tag.title`（日本語名）・`Tag.category`・`Tag.cuisine` は #81 で実装済み
- 送るのは検索の言葉だけ（ADR 0006）。ログにも出さない（アプリも Worker も）
- `project.pbxproj` は触らない。Worker の本番へのデプロイはこうせい。AI は `wrangler dev` を起動しない
- 実機での確認は要らない（Issue のとおり）

## 型と関数の口

### 条件（`Kouiunodeiindayo/Suggestion/SearchCondition.swift`、新規。M0）

```swift
/// 言葉から読み取った絞り込みの条件。`docs/suggestion-api.md` の /search の返りと同じ形。
struct SearchCondition: Equatable, Sendable {
    var tag: Tag?
    var favoriteOnly = false
    var period: SearchPeriod?
    /// 何も指定が無い（絞り込めない）
    var isEmpty: Bool { tag == nil && !favoriteOnly && period == nil }
}

enum SearchPeriod: String, CaseIterable, Sendable {
    case today, thisWeek = "this_week", thisMonth = "this_month", earlier
    var title: String   // 「今日」「今週」「今月」「今月より前」（チップの文字。M1）
}
```

- 置き場所は `Suggestion/`。`docs/architecture.md` のフォルダ構成で、`Suggestion/` は「ジャンルとタグの提案（機能26）、言葉で探す（機能28）」の置き場所と決まっているため

### 端末の中の読み取り（`Suggestion/LocalSearchParser.swift`、新規。M0）

```swift
/// 言葉の中から、タグの名前・「うまい」・時期の言葉を探して条件にする（通信しない）。
enum LocalSearchParser {
    static func parse(_ text: String) -> SearchCondition
}
```

- タグ：`Tag.allCases` の `title`（「ラーメン」「麺類」「和食」など）が言葉に含まれていれば、その `Tag`。複数当たったら、`Tag.allCases` の順で最初の 1 つ（`/search` の返りも 1 つだけのため）。ただし料理が当たったら料理を優先する（「ラーメン」と「麺類」を両方書いたら「ラーメン」）
  - 呼び名の揺れを少しだけ足す表（`aliases`）：「らーめん」→ ramen、「からあげ」「から揚げ」→ karaage、「すし」「鮨」→ sushi、「ぎょうざ」→ gyoza、「アイスクリーム」→ ice_cream、「ビール」「ワイン」「酒」→ alcohol、「麺」→ noodles、「中華料理」→ chinese。これ以上は M2（Jev）に任せる
  - 「野菜・サラダ」は「野菜」「サラダ」のどちらでも当たるようにする（`title` に「・」があるものは分けて探す）
- うまい：「うまい」「美味い」「旨い」「おいしい」「美味しい」「お気に入り」のどれかを含めば `favoriteOnly = true`
- 時期：要判断 7 の表。「今月」より「今日」「今週」を先に探す（「今日」を含む文に「今」だけで当たらないように、言葉ごとに探す）
- 大文字・小文字、全角・半角、ひらがな・カタカナの揺れは、`String.applyingTransform(.hiraganaToKatakana)` で両方をカタカナにそろえてから比べる（「らーめん」も「ラーメン」に当たる）

### 絞り込み（`Suggestion/RecordSearchFilter.swift`、新規。M0）

```swift
enum RecordSearchFilter {
    /// `records` は一覧の `@Query` の結果（仕分け済み・新しい順）。並びは変えない。
    static func filter(_ records: [Record], by condition: SearchCondition,
                       now: Date = .now, calendar: Calendar = .current) -> [Record]
    /// 記録にそのタグが当たるか。料理のタグは、その料理の大分類・系統にも当てはめる（data-model.md）
    static func matches(_ record: Record, tag: Tag) -> Bool
    static func matches(_ date: Date, period: SearchPeriod, now: Date, calendar: Calendar) -> Bool
}
```

- `matches(record, tag:)`：`record.tagValues` に `tag` がある、または `record.tagValues` のどれかの `category == tag` か `cuisine == tag`
- 時期：`today` は `calendar.isDate(date, inSameDayAs: now)`、`this_week` は `calendar.dateInterval(of: .weekOfYear, for: now)` の始まり以降、`this_month` は `dateInterval(of: .month, for: now)` の始まり以降、`earlier` は今月の始まりより前。未来の日付（機能13 で直したもの）は `this_week`・`this_month` に含める（`today` 以外は「始まり以降」で見るため）

### 一覧（`Features/List/RecordListView.swift`。M0・M1）

- `@State private var searchText = ""`、`@State private var condition: SearchCondition?`（`nil` は絞り込んでいない）、`@State private var message: String?`（読み取れなかった・通信できない）、`@State private var isSearching = false`（M2 の問い合わせ中）
- 欄（要判断 1 の A）：`TextField("ラーメン、うまい、今月 など", text: $searchText)`、`.submitLabel(.search)`、`.onSubmit { search() }`。右端に、文字があるときだけ ✕（押すと `clear()`）。読み上げ「言葉で探す」
- `search()`：`LocalSearchParser.parse(searchText)` が空でなければ `condition` に入れる。空なら M0 では `message = 読み取れなかった文言`（M2 は下）
- `clear()`：`searchText = ""`・`condition = nil`・`message = nil`。キーボードを閉じる（`@FocusState`）
- `displayed`：`condition.map { RecordSearchFilter.filter(records, by: $0) } ?? records`。`months` と `grid` はこれを使う（今は `records` を直接使っているところを置き換える）。詳細を開くときの並びも `displayed`（絞り込んだ中で左右にめくる）
- 絞り込み中は仕分け待ちの入口を隠す（要判断 6 の A）。合う記録が 0 件なら「合う記録がありません」＋「絞り込みをやめる」（`clear()`）
- M1：`condition` があるとき、欄の下に条件のチップ（`TagChipView` が #84 で共通になっていれば `isAttached: true` で使う。無ければ `Text` を角丸の墨の線で囲むだけの小さなビュー）＋「やめる」

### Worker（M2）

`docs/suggestion-api.md` を先に直す（下のステップ 8）。`server/src/`：

- `jev.ts`：`askJev(apiKey, state)` を `askJev(apiKey, state, questions, timeoutMs)` に広げる（今の `/suggest` は `buildQuestions()` と 1200 を渡す。読み取りの仕組み・503 の再試行はそのまま共通）。答えの型は、`read(id)` を質問のキーごとに呼ぶ今の形を、渡した `questions` のキーで回す形にする
- `search.ts`（新規）：
  - `parseQuery(body)`：`query` が文字列で 1〜100 文字（前後の空白を除いて数える）。違えば `BadRequestError`（400）
  - `buildSearchState(query)`：`"A user of a Japanese food diary app typed this search text. Pick conditions to filter their records.\ntext: <query>"`。改行は空白に置き換える（質問の形を崩されないように）
  - 質問 3 つ（どれも `choice`）
    - `tag`：34 個のタグのキー＋`none`。説明は「日本語名 / 英語」（例 `ramen: "ラーメン / ramen"`、`noodles: "麺類 / noodle dishes"`）。表は `tags.ts` に `SEARCH_TAGS` として置く（`docs/data-model.md` の表を写したもの。コメントで「表を変えたら data-model.md も」）
    - `favorite`：`yes`（うまかった・お気に入りだけ）／`no`
    - `period`：`today`・`this_week`・`this_month`・`earlier`（"before this month, e.g. 前に, 昔"）・`none`
  - しきい値：`SEARCH_MIN = 0.5`（`/suggest` の `GENRE_MIN` と同じ考え）。確率がこれ未満、または `none` なら指定なし（`null`／`false`）
  - 時間切れ：2500ms（アプリの 3 秒より先に 502）
- `index.ts`：`/search` を足す（`/suggest` と同じ順で 405・401・400・502）。ログは種類とエラーの文だけ（検索の言葉を出さない）
- `scripts/try-search.sh`（新規）：「前に食べたうまいラーメン」「今週の麺」「おいしかったケーキ」「こんにちは」を送って並べる。`try-suggest.sh` を写して作る

### アプリの問い合わせ（M2）

- `Suggestion/SuggestionClient.swift` に `func search(_ query: String) async throws -> SearchCondition` を足す。専用の `URLSession`（`timeoutIntervalForRequest`・`Resource` とも 3 秒、ephemeral）。返りは `tag` を `Tag(rawValue:)` で読めなければ `nil`、`period` を `SearchPeriod(rawValue:)` で読めなければ `nil`
- 画面から `SuggestionClient` を直接呼ばない（`docs/architecture.md`）。`SuggestionService` に `func search(_ query: String) async throws -> SearchCondition` を足す。本物は `SuggestionClient.search`（URL と合言葉が未設定なら `SearchUnavailable` を throw）。`SuggestionMock` は決まった条件を返す（`disabled` は throw）
- 一覧の `search()`（要判断 5 の A）：端末の中で読み取れたらそれで絞る。読み取れなければ `isSearching = true` で `suggestionService.search`。成功して空でなければ絞る、空なら「読み取れなかった」、throw なら「通信できませんでした…」。どれも、失敗したときは一覧をそのままにする

## ステップ

### M0（最小）

1. `Suggestion/SearchCondition.swift`・`LocalSearchParser.swift`・`RecordSearchFilter.swift`（新規）
2. `KouiunodeiindayoTests/LocalSearchParserTests.swift`（新規）：「前に食べたうまいラーメン」→ ramen・うまい・earlier／「らーめん」→ ramen／「今週の麺」→ noodles・this_week／「サラダ」→ vegetables／「ラーメンと麺類」→ ramen（料理を優先）／「おいしかったケーキ」→ cake・うまい／「今日」→ today（「今月」にならない）／「こんにちは」→ 空
3. `KouiunodeiindayoTests/RecordSearchFilterTests.swift`（新規。`TestStore` で記録を作る）：ramen だけの記録が noodles・chinese で当たる／tempura が japanese で当たり chinese で当たらない／うまいだけ／時期の 4 つ（`now` と `calendar` を固定して、週の始まりの境目・月の境目・未来の日付）／条件を組み合わせたとき全部を満たすものだけ／並びが変わらない。`Tag` は `Kouiunodeiindayo.Tag` と書く
   - 確認：`docs/rules/verification.md` の 1・2
4. `Features/List/RecordListView.swift`：欄・`displayed`・合う記録が無い・やめる。プレビューを足す：「検索の欄（空）」「絞り込み中（ラーメン）」「合う記録が無い」「読み取れなかった」（初期値を渡せるプレビュー専用の `init(searchText:)` を足し、`.onAppear` で `search()` を呼ぶ）、「SE 相当・文字サイズ XXX Large」
   - プレビューのデータは `SampleData.makePreviewContainer()`（ラーメン・うまいの記録・コーヒー・ケーキ・なし）で足りる。「前に」を見たいときは、先月の記録を 1 件足すコンテナを `HomePreviewData` か一覧用の小さなプレビューのデータに足す
   - 確認：スクショを `.verification/85/preview-RecordListView-*.png`
5. シミュレータで通し：一覧で「ラーメン」→ 絞れる → ✕ で戻る／「うまい」／「こんにちは」→ 読み取れなかった文言で一覧はそのまま／合う記録が無い言葉 → 表示と「絞り込みをやめる」。スクショと `notes.md`
6. `docs/architecture.md`：フォルダ構成の `Suggestion/` に 3 ファイル（「言葉で探す（機能28）の条件・端末の中の読み取り・絞り込み」）。`List/` の説明に「言葉で探す欄と、絞り込み」
7. コミット `feat: 一覧で、言葉から条件を読み取って記録を絞り込む (#85)`／`docs: 言葉で探す計画と構成を実装に合わせる (#85)`

### M1（条件のチップ）

8. `RecordListView`：条件のチップと「やめる」（要判断 3 の A）。プレビュー「絞り込み中」のスクショを撮り直す → コミット `feat: 言葉で探すときに、読み取った条件を見せる (#85)`
   - （2026-09-27 こうせい）チップは `TagChipView`（#84）の見た目を使う。タグ・「うまい」・時期を 1 つずつチップにし、欄の下に左から折り返して並べ（`FlowLayout`）、右端に「やめる」。チップの − を押すと、その条件だけ外して絞り直す（全部外れたら、やめるのと同じ）。`TagChipView` に、タグでない文字を渡せる `init(title:accessibilityLabel:isAttached:action:)` を足す
   - あわせて、時期の言葉に「今年」を足す（シミュレータで「今年」が読めなかった）。「今年」→ `this_year`（今年の 1 月 1 日以降。今週・今月と同じく、日付を未来に直した記録も入る）。`docs/suggestion-api.md` の `period` の表にも足す。テスト：`LocalSearchParserTests` に「今年のラーメン」→ ramen・this_year、`RecordSearchFilterTests` に年の境目
   - プレビュー：「絞り込み中（ラーメン・うまい・今月より前）」（先月以前のうまいラーメンを 1 件足したデータ）・「SE 相当・文字サイズ XXX Large」をチップつきで撮る。スクショは `.verification/85/m1-*.png`

### M2（Worker と問い合わせ）

9. `docs/suggestion-api.md` の `/search` を直す：返りの各項目は「Jev が選んだ確率が 0.5 未満なら指定なし」を足す／Worker 側の時間切れ 2.5 秒（アプリの 3 秒より先に 502）／「検索の言葉は保存しない・ログに出さない」を `/search` にも明記／アプリは端末の中で読み取れた言葉は送らない（要判断 5 の A）の一文
10. `server/src/jev.ts`・`search.ts`・`tags.ts`・`index.ts`・`scripts/try-search.sh`。確認：`cd server && npm run check`。`/suggest` の返りが変わっていないことは、こうせいが `try-real-labels.sh` で見る → コミット `feat: Worker に言葉で探す条件を返す /search を足す (#85)` → **こうせいにデプロイを 1 行で頼む**（デプロイ後、こうせいが `try-search.sh` を本番に向けて見る）
11. `SuggestionClient`・`SuggestionService`・`SuggestionMock`・`RecordListView` の `search()`。テスト：`SuggestionClientTests` に `/search` の組み立て（URL・メソッド・ヘッダー・本文 `{"query":…}`）と読み取り（知らないタグ・知らない時期は `nil`、壊れた JSON は throw）／`SuggestionServiceTests` に、URL と合言葉が未設定なら throw。プレビュー「通信できない」（`SuggestionMock.disabled`）→ コミット `feat: 端末で読み取れない言葉は Worker に聞いて絞り込む (#85)`

## ドキュメント（PR の本文に書く直し案。編集はこうせい）

- `docs/screen-design.md`「一覧」：必要な要素の「言葉で探す（機能28）」に「一覧の上に検索の欄。検索を押すと、読み取った条件（タグ・うまい・時期）で絞り込み、条件を見せる。やめると元の一覧に戻る。合う記録が無いときは、その旨と、絞り込みをやめるボタン」
- `docs/requirements.md`：変えない
- `docs/data-model.md`：変えない（「言葉で探す」の行のとおりに作る）

## リスク

- **時間が足りない**：優先度が一番低い。上の「最小の形と、削る順」のとおり、M0 で止めても PR にできる。M0 も無理なら着手しない
- **Jev が 34 個のタグから選ぶのを外す・遅い**：選択肢が多いと確率が割れて 0.5 に届かず、指定なしになりやすい。その場合は「読み取れなかった」になるだけで、壊れはしない。M2 の `try-search.sh` の結果で、しきい値を 0.4 に下げるかをこうせいと決める
- **端末の中の読み取りの取り違え**：「ケーキ屋さんでラーメン」のように 2 つ書くと、`Tag.allCases` の順で先のもの（ラーメン）になる。1 つしか選ばない決まり（`/search` の形）なので、そのままにする。チップ（M1）で何を読んだかが見えるので、言い直せる
- **「前に」の取り違え**（要判断 7）：「前に食べたうまいラーメン」の例文で、先月以前の記録しか出ないことになる。デモ機に今月のラーメンしか無いと 0 件になるので、デモで使う例文は、要判断 7 の答えとデモ機の記録に合わせて決める
- **一覧の `records` を `displayed` に置き換え漏れ**：月の見出しの計算・グリッド・詳細を開く並びの 3 か所。プレビュー「絞り込み中」で詳細を開いてめくり、絞り込んだ中だけを動くかを見る
- **検索の言葉がログに出る**：アプリ・Worker とも、ログには種類と件数だけを出す。レビューで見る
- **`project.pbxproj` の未コミットの変更**が作業ツリーに残っていたら、コミットに混ぜない。`git add` はファイルを指定する

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）・2（テスト。`LocalSearchParserTests`・`RecordSearchFilterTests` と既存のテストが全部通る）。M2 まで作ったら 5（Worker。`npm run check`。`wrangler dev` と本番の確認はこうせい）
- プレビュー：M0 の 5 つ（M1 ならチップつき）のスクショ
- シミュレータ：M0 のステップ 5 の通し。Issue の完成の条件「言葉で絞り込める・やめると戻る」はここで見る。「通信できないとき」は M2 まで作ったときだけ、プレビュー「通信できない」とシミュレータ（Worker の URL が未設定の状態）で見る
- 実機：要らない（Issue のとおり）
- `git status` で `project.pbxproj` と `Config/Local.xcconfig` がコミットに入っていない
