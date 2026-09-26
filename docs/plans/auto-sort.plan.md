# 実装計画: 仕分けの「おまかせ」で、自信がある写真だけ AI が勝手に仕分ける

## 概要

仕分けの画面に「おまかせ」ボタンを置く。押すと、提案のジャンルの確率がしきい値（0.8 から始める）以上の写真だけが、そのジャンルの向きへ今のスワイプと同じ動きで飛んでいき、提案のタグも付いて確定する。自信の無い写真は残り、人が仕分ける。Worker の `/suggest` の返りにジャンルの確率を足し、アプリはそれを `Record` に保存して判定に使う。対応する Issue：#103（親 #86）。対応する機能：`docs/requirements.md` の機能26（ジャンルとタグの提案）に「おまかせで AI に任せることもできる」を足す（要件の書き換えはこうせい）。

受け渡しの形は `docs/suggestion-api.md`、データの形は `docs/data-model.md`、書き込みは `docs/architecture.md`「書くとき」、仕分けの画面の作りは `docs/plans/sort-suggestion.plan.md`（#83）が正。**#102（`docs/plans/photo-import.plan.md`）の後に実装する**。仕分けの画面を共有するので、下の「#102 との関係」を守る。

## 決めたこと（全部推奨、2026-09-27 こうせい確認）

本文の「要判断 n」は、この番号を指す。

1. **ボタンの置き場所と見た目**：上の行の右端（左端の ✕ と左右対称）。`wand.and.stars` ＋「おまかせ」、墨の線の角丸のボタン。カードの外に置く
2. **任せられる枚数**：「おまかせ 5」のように、今しきい値を超えている枚数を小さく添える。提案が届くたびに増える。0 のときは薄く見せる
3. **任せられる写真が 0 枚のとき**：ボタンは薄く、押すと上の行の下に 2 秒だけ「自信のある写真がまだありません」
4. **自信の無い写真が先頭にあるとき**：次に飛ばす写真（任せられる写真のうち並び順で最初のもの）を先頭に出してから飛ばす。自信の無い写真は後ろに回り、終わると元の並びで残る
5. **飛ばす速さ**：1 枚ごとに、先頭に出す → 0.25 秒止めてスタンプを見せる → 0.3 秒で飛ぶ → 次まで 0.2 秒
6. **おまかせの間の操作と止め方**：ボタンが「止める」（`stop.fill`）に変わる。押すと、飛んでいる 1 枚は飛び切って保存し、次からは飛ばさない。✕ でも止まって抜ける。おまかせの間は、カードのドラッグ・ラベル・タグのチップ・「う、うまい」は押せない
7. **終わったときの知らせ**：上の行の下に 2 秒だけ「5 枚おまかせしました」。全部終わって 0 枚になったら、今どおり画面を閉じてホームへ
8. **撮った直後の 1 枚だけの仕分け**：ボタンを出さない。入口からの仕分けと、#102 の取り込みからの仕分けだけに出す
9. **しきい値の置き場所**：Worker は確率をそのまま返し、アプリが保存して、しきい値 0.8 はアプリの定数に置く。`suggestion-api.md` の一文を「提案を出すかの境目は Worker に置く。おまかせで任せるかの境目はアプリ」に直す

## 実装で計画から変えたこと（2026-09-27）

- 上の行を、左の ✕・真ん中の「あと n 枚」・右の「おまかせ」の 3 つに分け、左右の枠を同じ幅にした（今までは ZStack で重ねていた）。真ん中の文字が中央からずれず、文字が大きくてもボタンと重ならない。ボタンの文字は Large で止め、それでも入らない幅（375pt で XXX Large 以上）ではアイコンと枚数だけにする
- 知らせ（2 秒）は、上の行の高さを測って、その下にカードの上から重ねる（出る・消えるでカードの大きさが変わらないように）。読み上げには、出たときにアナウンスで知らせる
- おまかせの途中の ✕ は、飛んでいる 1 枚が保存されてから閉じる（`dismissesAfterFlight`）。今までどおり、手で飛ばしている間は ✕ を押せない
- 飛ぶ時間は、ラベルを押したときと同じ 0.25 秒のまま（計画の 0.3 秒にしていない。止め 0.25 秒と次まで 0.2 秒は計画どおり）
- `SwipeDirection` の逆引きは `init?(suggestedGenre:)`（食べ物・飲み物・デザートだけ。なし・仕分け待ちは nil）。任せられる枚数を数える `AutoSortPolicy.eligibleCount(in:)` を足した
- `SuggestionResult` は `init(genre:genreConfidence:tags:)` の `genreConfidence` を既定 nil にした（今の呼び出しを直さずに済む）
- 動きは、確認のときだけアプリの入口に提案のモックを渡す仮の変更（コミットしない）で、シミュレータで確かめた（`.verification/103/notes.md`）

## 前提・確認事項

- ブランチは `feat/103-auto-sort`。#102（`feat/102-photo-import`、レビュー済み・未マージ）の上に積んである。#102 に直しが入ったら、`feat/102` で直してからこのブランチを rebase する。main には #101（仕分けの点線とチップ）・#99（料理のタグのしきい値）が入っていて、#99 の Worker は本番にデプロイ済み
- `project.pbxproj` は触らない。新しいファイルは同期フォルダに置くだけ
- Worker の本番へのデプロイはこうせいが行う（`cd server && npm run deploy`）。AI は `wrangler dev` を起動しない（`docs/rules/verification.md` の 5）
- **返りに項目を足すのは、どちらの順で出しても壊れない**：古いアプリは知らない項目を読み飛ばす（`JSONDecoder` は余分なキーを無視する）。新しいアプリが古い Worker を呼ぶと、確率が無い＝おまかせの対象にならないだけ。デプロイとアプリの入れ替えの順を気にしなくてよい
- **これまでに提案が届いた写真は、確率を持っていない**（`suggestedAt` が入っているので、問い合わせ直さない）。おまかせの対象にはならない。デモ用の写真は、Worker をデプロイしてアプリを入れ替えたあとに、改めて取り込む（#102）か撮る
- Jev の `genre` の確率は、`probabilities[choice]`（#80 の計測で、正しい答えは 0.87〜1.0、迷うと下がる。`docs/plans/suggestion-worker.plan.md`）。Worker は 0.5 未満ではジャンルを返さない（`GENRE_MIN`）ので、アプリに届く確率は 0.5〜1.0
- 効果音（`SoundPlayer`）はまだ無い。おまかせでも鳴らさない（手で仕分けたときと同じ。#22 で付けるときに一緒に鳴る）
- 振動は今の `commit` の中の `sensoryFeedback` がそのまま効く（1 枚飛ぶごとに 1 回）

### #102 との関係（矛盾させない決まり）

- #102 は `SortView` に `init(importedIDs:importSummary:)` と `visibleRecords`（`@Query` の結果を取り込みの id で絞ったもの）と、上の行の下の件数の 1 行を足す。**おまかせは `visibleRecords` の中だけで動く**（取り込みからの仕分けなら、取り込んだ写真だけを任せる）
- 上の行の下は、#102 の件数の 1 行と、この Issue の 2 秒の知らせ（要判断 3・7）が重なりうる。知らせは件数の行の**下**に出す（件数の行は動かさない）
- 先頭を入れ替える（要判断 4 の A）のは、`visibleRecords` のあとに掛ける並べ替え（`displayedRecords`）で行う。`visibleRecords` 自体は変えない
- 取り込みからは提案を頼まず、仕分けを開いたときに並び順に頼む（#102 の前提）。おまかせの対象は、提案が届いた順に増えていく

## 型と関数の口

### Worker（`server/src/`）

`suggest.ts` の `Suggestion` に `genreConfidence: number | null` を足す：

```ts
export interface Suggestion {
  genre: Genre | null;
  // genre を返すときの Jev の probabilities[genre]。小数第 2 位に丸める。genre が null なら null
  genreConfidence: number | null;
  tags: string[];
}
```

- `suggest()` の中で、`genre` を決めたあと `genreConfidence = genre === null ? null : Math.round(answers.genre.confidence * 100) / 100`
- ラベルが 0 個のときの `{ genre: null, tags: [] }` にも `genreConfidence: null` を足す
- `index.ts` は変えない（`suggest()` の返りをそのまま JSON にしている）
- `try-suggest.sh`・`try-real-labels.sh` は返りをそのまま出すので、変えなくても確率が見える

### アプリ

`Suggestion/SuggestionClient.swift`：

```swift
struct SuggestionResult: Equatable {
    let genre: Genre?
    /// ジャンルの確率（0〜1）。ジャンルが無い・古い Worker で項目が無い・範囲の外なら nil
    let genreConfidence: Double?
    let tags: [Tag]
    static let empty = SuggestionResult(genre: nil, genreConfidence: nil, tags: [])
}
```

- `Response` に `let genreConfidence: Double?` を足す（無ければ `nil`）。`decodeResult` で、`genre` が読めたときだけ、かつ 0...1 のときだけ残す。それ以外は `nil`（落とさない）
- 既存の `SuggestionResult(genre:tags:)` の呼び出し（`SuggestionMock`・テスト）は、`genreConfidence:` を足して直す

`Data/Record.swift`：

```swift
/// 提案したジャンルの確率（0〜1。Jev の probabilities）。おまかせで任せるかの判定に使う。
/// 提案が無い・まだ問い合わせていない・確率を返す前の Worker で問い合わせた記録は nil。
var suggestedGenreConfidence: Double? = nil
```

`Data/RecordStore.swift` の `saveSuggestion`：

```swift
func saveSuggestion(genre: Genre?, genreConfidence: Double? = nil, tags: [Tag], for id: UUID, at date: Date = .now)
```

- `suggestedGenre` を書くのと同じ条件で、書いたジャンルが `nil` でなければ `genreConfidence` を、`nil` なら `nil` を書く（提案できないジャンルを捨てたときに、確率だけ残らないように）
- 既定値 `nil` にするので、今の呼び出し（`SampleData`・テスト）はそのまま通る

`Suggestion/SuggestionService.swift`：`store.saveSuggestion(genre: result.genre, genreConfidence: result.genreConfidence, tags: result.tags, for: job.id)`。ログの「提案が届いた」に確率も出す（`0.93` のような数だけ。ラベルは出さない）

`Suggestion/SuggestionMock.swift`：`ramen` を確率 0.95 にし、`ramenUnsure`（食べ物・確率 0.6・同じタグ）を足す。`requestSuggestion` で確率も渡す

### おまかせの判定（`Features/Sort/AutoSortPolicy.swift`、新規）

```swift
/// おまかせで任せてよい写真の決まり（機能26）。
enum AutoSortPolicy {
    /// 任せる確率の境目。0.8 から始めて実機で調整する（#80 の計測で、Jev の正しい答えは 0.87〜1.0 に集まっていた）。
    /// 変えたら、値と理由をこのコメントと docs/plans/auto-sort.plan.md の「決めたこと」に書く
    static let threshold = 0.8

    /// 仕分け待ちで、提案のジャンルがあり、その確率が境目以上。
    static func isEligible(_ record: Record) -> Bool

    /// 任せられる写真のうち、並び順で最初のもの。無ければ nil。
    static func nextTarget(in records: [Record]) -> Record?
}
```

### 仕分けの画面

`Features/Sort/SortCardStackView.swift`：外から 1 枚飛ばしてもらう口を足す。

```swift
/// おまかせで、先頭の写真を飛ばしてほしいとき。`token` が変わるたびに 1 回だけ飛ばす
struct AutoFlightRequest: Equatable {
    let token: UUID
    let recordID: UUID
    let direction: SwipeDirection
}

/// 引数に足す（既定は nil。今の呼び出しはそのまま）
let autoFlightRequest: AutoFlightRequest?
/// おまかせの間。ドラッグ・ラベル・「う、うまい」を受け付けない（`isCommitting` と同じ扱い）
let isAutoSorting: Bool
```

- `.onChange(of: autoFlightRequest)`：`request.recordID == records.first?.id` のときだけ、今の `commit(request.direction, screenSize:)`（ラベルを押したときと同じ、まっすぐ飛ぶ版）を呼ぶ。`commit` に要る `screenSize` は、`GeometryReader` の大きさを `@State private var areaSize` に控えて使う
- 要判断 5 の A の「止めてスタンプを見せる」：飛ばす前に、飛ぶ向きのスタンプとラベルの強調を出す。`commit` の中で `flyingDirection` を先に入れて 0.25 秒待ってから `flyOffset` を動かす形にする（`commit` に `pause: Duration = .zero` の引数を足す。手のスワイプ・ラベルは 0 のまま）
- ジェスチャー・ラベル・「う、うまい」の「受け付けない」の条件を `isCommitting || isAutoSorting` にする
- 保存は今の `onSort` の経路のまま（`SortView` が `SortTagSelection.commit` を呼ぶ ＝ `setTags` → `setGenre`）。**おまかせ専用の保存の関数は作らない**（Issue の決定）

`Features/Sort/SortView.swift`：

- `@State private var isAutoSorting = false`、`@State private var autoTargetID: UUID?`、`@State private var autoFlightRequest: AutoFlightRequest?`、`@State private var autoSortedCount = 0`、`@State private var notice: String?`（2 秒の知らせ）
- `displayedRecords`：`visibleRecords`（#102）の `autoTargetID` の記録を先頭に移したもの（要判断 4 の A）。`SortCardStackView`・タグの行・「あと n 枚」はこれを使う
- 上の行の右端にボタン（要判断 1・2・6）。`singleRecordID != nil`（カメラから）のときは出さない（要判断 8）。読み上げ「おまかせで仕分ける。任せられる写真 n 枚」／「おまかせを止める」
- おまかせの流れは `.task(id: isAutoSorting)` の中の 1 本のループにする（止める・画面を抜けると `Task` が取り消されて止まる）：
  1. `guard let next = AutoSortPolicy.nextTarget(in: displayedRecords)` が無ければ終わる（`isAutoSorting = false`、要判断 7 の知らせ）
  2. `autoTargetID = next.id` → 先頭が入れ替わるのを待つ（`await Task.yield()` のあと 0.05 秒）
  3. `autoFlightRequest = AutoFlightRequest(token: UUID(), recordID: next.id, direction: SwipeDirection(genre: next.suggestedGenreValue))`（`Genre` → 向きの逆引きを `SwipeDirection` に足す。`food`→上・`drink`→左・`dessert`→右）
  4. 飛び終わって先頭が変わるまで待つ（`isCommitting` が true → false になるのを 0.05 秒ごとに見る。上限 2 秒で打ち切り、止める）
  5. `autoSortedCount += 1`、0.2 秒待って 1 に戻る
- 止めたとき（ボタン・✕）：`isAutoSorting = false`。飛んでいる 1 枚は飛び切って保存される（取り消さない）。`autoTargetID = nil` に戻し、並びを元に戻す
- 飛ばした写真の外したタグ：`removed(for:)` の今の値を使う（おまかせを押す前に、先頭の写真のチップを外していたら、それを守る）
- 0 枚のとき（要判断 3）：`notice = "自信のある写真がまだありません"`、2 秒後に消す
- 最後の 1 枚を飛ばして 0 枚になったら、今の `.onChange(of: records.isEmpty)` で閉じる（変えない。#102 の取り込みの版は `visibleRecords.isEmpty` に合わせてあるはず。合わせてなければ #102 に合わせる）

## ステップ

先に Worker（デプロイに人の手が要るので、早く渡す）。そのあとアプリをデータ → 判定 → 画面の順に。

### フェーズ 1：受け渡しの形と Worker

1. `docs/suggestion-api.md` — 返る の例と表に `genreConfidence` を足す：「数値か `null`。`genre` を返すときの確率（0〜1、小数第 2 位）。`genre` が `null` なら `null`。アプリはおまかせで任せるかの判定に使う（`docs/data-model.md` の `suggestedGenreConfidence`）」。提案なしの例も `{ "genre": null, "genreConfidence": null, "tags": [] }` に。「確信度の扱い」に要判断 9 の一文。「古いアプリは知らない項目を読み飛ばす」も 1 行
2. `server/src/suggest.ts` — 上の口のとおり
3. 確認：`cd server && npm run check` が通る。`docs/plans/suggestion-worker.plan.md` に計測のメモがあれば、そこへは書き足さない（この計画の「決めたこと」に書く）
4. コミット `feat: 提案の返りにジャンルの確率を足す (#103)` → **こうせいに「Worker のデプロイを頼む」と 1 行で伝えて先に進む**（デプロイ後の確認は、こうせいが `try-real-labels.sh` を本番に向けて、`genreConfidence` が返ることを見る）

### フェーズ 2：アプリのデータ

5. `docs/data-model.md` — `Record` の表に `suggestedGenreConfidence | Double? | 提案したジャンルの確率（0〜1）。おまかせ（機能26）で任せるかの判定に使う。提案したジャンルが無い・まだ問い合わせていない・確率を返す前の Worker で問い合わせたときは nil`。「よく使う取り出し方」に「おまかせで任せる写真｜仕分けの画面に出ている写真のうち、`suggestedGenre` があり、`suggestedGenreConfidence` が境目（アプリの定数）以上｜画面の並び順」
6. `Data/Record.swift`・`Data/RecordStore.swift`・`Suggestion/SuggestionClient.swift`・`Suggestion/SuggestionService.swift`・`Suggestion/SuggestionMock.swift` — 上の口のとおり
7. テスト（`KouiunodeiindayoTests/`）
   - `SuggestionClientTests`：`{"genre":"food","genreConfidence":0.93,"tags":[]}` → 0.93／項目が無い → nil／`genre` が null で確率だけある → nil／1.5・-0.1 → nil／知らないジャンル（`unsorted`）→ ジャンルも確率も nil
   - `RecordStoreTagsTests`（か新しい `RecordStoreSuggestionTests`）：確率つきで保存される／ジャンルが提案できない値（`noGenre`）なら確率も nil／問い合わせ済みなら書き換えない（今のテストに確率を足す）
   - `SuggestionServiceTests`：差し替えた `suggest` が確率つきの結果を返すと、記録に確率が入る
   - 確認：`docs/rules/verification.md` の 1・2
8. コミット `feat: 提案のジャンルの確率を読んで記録に保存する (#103)`

### フェーズ 3：判定

9. `Features/Sort/AutoSortPolicy.swift`（新規）と `SwipeDirection` の `Genre` からの逆引き
10. `KouiunodeiindayoTests/AutoSortPolicyTests.swift`（新規）：0.8 ちょうど → 任せる／0.79 → 任せない／確率 nil → 任せない／ジャンル nil で確率だけ（あり得ないが）→ 任せない／仕分け済み → 任せない／`nextTarget` が並び順の最初の任せられる写真を返す（先頭が自信なしでも飛ばして 2 枚目）／全部自信なし → nil。逆引き：`food`→`.up`・`drink`→`.left`・`dessert`→`.right`・`noGenre`・`unsorted`→ nil
11. コミット `feat: おまかせで任せる写真の判定を足す (#103)`

### フェーズ 4：仕分けの画面

12. `Features/Sort/SortCardStackView.swift` — 外から飛ばす口・`isAutoSorting`・`pause`
13. `Features/Sort/SortView.swift` — ボタン・`displayedRecords`・ループ・止め方・知らせ
14. `Features/Sort/SortPreviewData.swift` — `makeAutoSortContainer()`：仕分け待ち 4 件（確率 0.95 の食べ物・0.9 の飲み物・0.6 の食べ物・提案なし）。並びは自信なしが先頭に来るようにする（要判断 4 の確認用）。`SampleData.makeImage` の色で見分ける
15. プレビューを足す（`SortView.swift`）：「おまかせ・任せられる 2 枚」「おまかせ・0 枚」（ボタンが薄い）「おまかせ中」（`init` にプレビュー専用の `startsAutoSorting: Bool` を足し、`.onAppear` で始める。静止画では最初の 1 枚が先頭に出てスタンプが出た瞬間になる）「幅 375pt・文字サイズ XXX Large」（上の行の ✕・あと n 枚・おまかせが重ならない）。#102 の「取り込みから」のプレビューでもボタンが出ることを見る
   - 確認：プレビューのスクショを `.verification/103/preview-SortView-auto-*.png` に。既存の仕分けのプレビュー（1 枚・複数枚・カメラから・提案あり・ドラッグ途中）が変わっていない（カメラからはボタンなし）
16. 確認：ビルド・テスト。シミュレータでは Vision が失敗して提案が届かないことがあるので、動きはプレビューのキャンバスを動かして（Live）見る。おまかせを押す → 2 枚飛んで 2 枚残る → 止める・✕ で止まる。キャンバスの操作ができない環境なら、ここは実機に回して notes.md に書く
17. コミット `feat: 仕分けに「おまかせ」を足し、自信のある写真を飛ばす (#103)`

### フェーズ 5：ドキュメントと記録

18. `docs/architecture.md` — フォルダ構成の `Sort/` に `AutoSortPolicy.swift`（おまかせで任せる写真の決まりと境目）を足す。`SortView.swift` の説明に「おまかせ（任せられる写真を先頭に出して、`SortCardStackView` に 1 枚ずつ飛ばしてもらう）」。「提案（機能26）の流れ」に「Worker はジャンルの確率も返し、`suggestedGenreConfidence` に保存する。おまかせは、画面に出ている写真のうち確率が境目以上のものだけを、手で仕分けたときと同じ書き込み（タグ → ジャンル）で確定する」
19. `.verification/103/notes.md` — 下の実機の表と、しきい値を試した結果
20. PR の本文に、`docs/requirements.md`・`docs/screen-design.md` の直し案（下の「ドキュメント」）。この 2 つは編集しない
21. 実機で試してしきい値を決めたら（こうせい）、`AutoSortPolicy.threshold` のコメントと、この計画の「決めたこと」（下に節を足す）に値と理由を書く → コミット `docs: おまかせのしきい値と計画を実機の結果に合わせる (#103)`

## 実機での確認（こうせいが行う。`.verification/103/notes.md` にも同じ表）

前もって：Worker をデプロイし、新しいアプリを入れてから、#102 の取り込みで料理・飲み物・デザート・料理でないものを混ぜて 10〜15 枚取り込む（提案が届くまで仕分けを開いたまま 30 秒ほど待つ）。

| 操作 | 見るところ |
|---|---|
| 仕分けを開く | 「おまかせ n」の数が、提案が届くにつれて増える（要判断 2 の A のとき） |
| 「おまかせ」を押す | 自信のある写真だけが、提案のジャンルの向きへ 1 枚ずつ飛ぶ。スタンプが見える。振動が 1 枚ごとに来る。自信の無い写真・提案なしは残る |
| 終わったあと、一覧を見る | 飛んだ写真にジャンルと提案のタグが付いている（手でスワイプしたときと同じ） |
| おまかせの途中で「止める」 | その 1 枚が飛び切ったところで止まる。残りは手で仕分けられる |
| おまかせの途中で ✕ | 止まってホームに戻る。飛ばなかった写真は仕分け待ちに残る |
| 先頭の写真のチップを 1 つ外してから「おまかせ」 | その写真が任せられるなら、外したタグは付かずに保存される |
| 自信のある写真が 0 枚の状態で押す | 要判断 3 の見た目 |
| 機内モードにして仕分けを開く | 手での仕分けは今どおり。すでに提案が届いている写真は、機内モードでもおまかせで飛ぶ（デモの保険） |
| しきい値の手応え | 飛んだ写真のうち間違ったジャンルの枚数と、残った写真のうち飛んでよかった枚数を数える。間違いが 1 割を超えるなら上げる（0.9）、ほとんど飛ばないなら下げる（0.7）。値は Xcode のコンソールの「提案が届いた」のログの確率を見て決める |

## ドキュメント（PR の本文に書く直し案。編集はこうせい）

- `docs/requirements.md` の機能26：「決めるのは本人」のあとに「おまかせで AI に任せることもできる（自信がある写真だけ。自信が無い写真は残る）」
- `docs/screen-design.md` の「仕分け」
  - 必要な要素：「おまかせ（機能26）。押すと、提案のジャンルに自信がある写真だけ、そのジャンルの向きへ勝手に飛んでいき、提案のタグも付いて確定する。自信が無い写真は残る。もう一度押すか、仕分けを抜けると止まる。仕分け待ちへの入口・アルバムからの取り込みから入ったときだけ出す」
  - 操作の表：「おまかせを押す｜自信のある写真が 1 枚ずつ飛んでいく。任せられる写真が無いときは、その旨を出す」「おまかせ中にもう一度押す｜止まる。飛んでいる 1 枚は確定する」
  - 状態：「おまかせ中」「任せられる写真が無い」

## 時間が足りないときに削る順（締め切り 9/27 13:00）

Issue のメモのとおり、#102 が 9 時ごろまでに実機で動いていなければ着手しない（デモの台本で「次はここまで AI に任せる」と語る）。着手したら、上から削る。

1. 終わったときの知らせ（要判断 7）→ 出さない
2. ボタンの枚数（要判断 2）→ 出さない。0 枚のときは押したら知らせるだけ（要判断 3 の B）
3. 飛ぶ前にスタンプを見せる止め（要判断 5）→ 止めずに飛ばす（`pause` を足さない）
4. 先頭の入れ替え（要判断 4 の A）→ B（先頭が自信なしなら止まる）。`displayedRecords` を足さずに済む。デモでは自信のある写真が先頭に来るよう、取り込む順を選ぶ
5. フェーズ 5 のドキュメントの直し案 → PR に 1 行で「あとで出す」と書き、`architecture.md`・`data-model.md`・`suggestion-api.md` だけは直す（完成の条件のため）
6. フェーズ 4 全部（画面）→ 見送り。フェーズ 1〜3 はマージしてよい（確率が記録に残るだけで、動きは変わらない）

## リスク

- **Worker のデプロイ前に作ったデモ用の写真は、確率を持っていない**。対象にならず、「おまかせ 0」になる。デプロイ → アプリを入れ替え → 取り込み直し、の順をこうせいに伝える（前提・確認事項）
- **Jev の確率が偏っていて、ほとんど 0.8 を超える**（#80 の計測で正解は 0.87〜1.0、迷うときは `other` に寄る）。間違いまで飛ぶなら 0.9 に上げる。逆に、実機の弱いラベルだと 0.8 未満ばかりのこともある。どちらも実機の表で見る
- **先頭の入れ替えで、カードが跳ねて見える**（`SortCardStackView` は記録の id でカードを並べるので、入れ替えると後ろのカードの位置から手前に来る）。気になるなら入れ替えのときだけアニメーションを切る（`withTransaction` の `disablesAnimations`）。それでも気になれば削る順の 4
- **ループと飛ぶ処理の待ち合わせがずれて、止まらない・二重に飛ぶ**。`AutoFlightRequest` の `token` と `recordID` の一致を見る・`isCommitting` の間は次を頼まない・2 秒で打ち切る、の 3 つで守る。✕ で閉じると `.task` が取り消されるので、閉じたあとに飛ぶことは無い
- **おまかせの途中に提案が届く**と、任せられる写真が途中で増える。ループが毎回 `nextTarget` を探すので、自然に含まれる（止めるまで続く）
- **#102 と同じ `SortView` を触る**。#102 がマージされてから作る。`SortView` の変更は、ボタン・`displayedRecords`・`.task` のループ・知らせの行に留め、#102 の件数の行と `visibleRecords` はそのまま使う
- **テストで `Tag` が Swift Testing の `Tag` とぶつかる**（#83 で既知）。`Kouiunodeiindayo.Tag` と書く
- **`project.pbxproj` の未コミットの変更**が作業ツリーに残っている。コミットに混ぜない。`git add` はファイルを指定する

## 完成の確認方法

- Worker：`cd server && npm run check`。デプロイと本番の確認（`genreConfidence` が返る）はこうせい
- `docs/rules/verification.md` の 1（ビルド）・2（テスト。`AutoSortPolicyTests` と、確率を足した既存のテストが全部通る）
- プレビュー：フェーズ 4 のプレビューのスクショ。既存の仕分けのプレビューが崩れていない
- 実機（こうせい）：上の表。Issue の完成の条件の「飛ぶ・残る・止められる・しきい値を決めた」はここで見る。**実機確認が済むまで、PR の「実機での確認」は「未」で出す**
- `git status` で `project.pbxproj` と `Config/Local.xcconfig` がコミットに入っていない
