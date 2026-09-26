# 提案の受け渡しの形

アプリと Worker（中継サーバー）の間で、何を送って何が返るか。アプリ側（`Suggestion/`）と Worker 側（`server/`）は、この形に合わせて作る。
Worker を挟む理由と構成は `docs/adr/0006-suggestion-vision-jev.md`。アプリの中の流れは `docs/architecture.md` の「提案（機能26）の流れ」。
形を変えるときは、コードより先にこのファイルを直す。

## 共通

- アプリは、自分たちの Cloudflare Worker（`server/`）を呼ぶ。Jev（Workers AI）を直接呼ばない
- 入口は2本：`POST /suggest`（機能26）と `POST /search`（機能28）
- どちらも `POST`。ヘッダーは次の2つ
  - `Content-Type: application/json`
  - `Authorization: Bearer <合言葉>`
- 合言葉は、Worker の secret（Cloudflare 側に置く、コードに書かない値）と、アプリの `Config/Local.xcconfig`（git に入れない）に置く
- JSON の項目名は camelCase（`favoriteOnly` のように、2語目から大文字で始める書き方）
- タグ・ジャンルの値は、`docs/data-model.md` の「ジャンルの値」「タグの値」のキーのまま使う
- Worker は、受け取った内容を保存しない。ログにも残さない（ADR 0006）

### 時間切れと失敗

| 入口 | 時間切れ（アプリ側） |
|---|---|
| `/suggest` | 1.5 秒 |
| `/search` | 3 秒 |

- アプリは、200 以外・時間切れ・通信できない、をどれも同じ「失敗」として扱う
- `/suggest` が失敗したら、アプリはその場で 2 秒・5 秒あけて最大 2 回問い合わせ直す。それでもだめなら何も保存しない（`suggestedAt` は `nil` のまま）。次に仕分けの画面を開いたときに、もう一度問い合わせる（`docs/architecture.md`）
- `/search` が失敗したら、通信できない旨を出して、一覧はそのままにする

## `POST /suggest`（機能26）

写真のラベルを送り、ジャンルとタグの提案を受け取る。

### 送る

```json
{
  "labels": [
    { "name": "ramen", "confidence": 0.62 },
    { "name": "soup", "confidence": 0.12 },
    { "name": "chopsticks", "confidence": 0.08 }
  ]
}
```

| 項目 | 型 | 内容 |
|---|---|---|
| `labels` | 配列 | Vision（`ClassifyImageRequest`）の結果。確信度の高い順に、1個以上・最大 20 個 |
| `labels[].name` | 文字列 | Vision のラベルの identifier（ラベルを表す英語の名前）そのまま。英小文字・数字・`_` だけで、64 文字以内のものを使う（下の「ラベルの名前の扱い」） |
| `labels[].confidence` | 数値 | 確信度。0〜1 で、小数第2位に丸める |

### ラベルの名前の扱い

- ラベルの名前は Jev への質問に入る。変な文字を入れないため、使うのは英小文字・数字・`_` だけで 64 文字以内のものに限る
- 合わないラベルは、Worker が捨てて残りで判断する。400 にはしない（1つのラベルのせいで、その写真の提案が毎回失敗するのを避けるため）
- 捨てた結果が0個なら、提案なしの 200 を返す
- 400 になるのは、`labels` が配列でない・0個・20 個を超える、`name` が文字列でない、`confidence` が 0〜1 の数値でない、のとき

### 確信度の扱い

- 確信度を「強い・弱い」の言葉に分けるのは Worker。Jev には数値を渡さない（ADR 0006）。提案を出すかの境目は Worker に置く。アプリを入れ直さずに調整できるようにするため
- おまかせ（機能26）で任せるかの境目は、アプリに置く（返りの `genreConfidence` を記録に保存して、アプリの定数と比べる。境目を変えると、提案が届き済みの写真にもすぐ効く）

### 返る

提案があるとき：

```json
{ "genre": "food", "genreConfidence": 0.93, "tags": ["ramen", "noodles", "chinese"] }
```

自信が低いとき（提案なし）：

```json
{ "genre": null, "genreConfidence": null, "tags": [] }
```

| 項目 | 型 | 内容 |
|---|---|---|
| `genre` | 文字列か `null` | `food`／`drink`／`dessert` のどれか。提案しないときは `null`。`unsorted`・`none` は返さない |
| `genreConfidence` | 数値か `null` | `genre` を返すときの確率（0〜1、小数第2位）。`genre` が `null` なら `null`。アプリはおまかせで任せるかの判定に使う（`docs/data-model.md` の `suggestedGenreConfidence`） |
| `tags` | 文字列の配列 | タグのキー。重複なし。空でもよい。`genre` が `null` でも、`tags` があることはある |

- 提案なしも **200** で返す。アプリはこれを受けて `suggestedAt` を書く（問い合わせ済みにする）
- Worker は、`docs/data-model.md` にあるキーだけを返す。アプリは、知らないキーが来たら捨てる（落とさない）
- 古いアプリは知らない項目（`genreConfidence`）を読み飛ばす。新しいアプリが古い Worker を呼ぶと、確率が無い＝おまかせの対象にならないだけ。Worker のデプロイとアプリの入れ替えは、どちらが先でもよい
- 料理のタグは、対応する Vision のラベルが `labels` にあるときだけ返す（`docs/data-model.md` の「タグの値」）

## `POST /search`（機能28）

検索の言葉を送り、絞り込みの条件を受け取る。絞り込みはアプリが端末の中で行う。記録は送らない。

### 送る

```json
{ "query": "前に食べたうまいラーメン" }
```

| 項目 | 型 | 内容 |
|---|---|---|
| `query` | 文字列 | 検索の言葉。1〜100 文字 |

### 返る

```json
{ "tag": "ramen", "favoriteOnly": true, "period": "earlier" }
```

| 項目 | 型 | 内容 |
|---|---|---|
| `tag` | 文字列か `null` | タグのキー1つ。`null` は指定なし |
| `favoriteOnly` | 真偽値 | `true` なら「うまい」の記録だけ |
| `period` | 文字列か `null` | 時期。下の表のどれか。`null` は指定なし |

| `period` | 意味 |
|---|---|
| `today` | 今日 |
| `this_week` | 今週の始まりから今まで。今日も含む（週の始まりは端末の設定） |
| `this_month` | 今月1日から今まで。今日も含む |
| `earlier` | 今月1日より前 |

- 時期の区切りは暦。アプリが端末の中で `takenAt` に当てはめる
- 何も読み取れなかったときも 200 で返し、全部を指定なしにする

```json
{ "tag": null, "favoriteOnly": false, "period": null }
```

## エラー

形は2つの入口で共通。

```json
{ "error": { "code": "unauthorized", "message": "..." } }
```

| HTTP | `code` | 起きるとき |
|---|---|---|
| 400 | `bad_request` | JSON が読めない・項目が足りない・型が違う・値の範囲の外（`labels` が0個か 20 個を超える、`confidence` が 0〜1 の外、`query` が 1〜100 文字の外）。形に合わないラベルの名前は 400 にしない（上の「ラベルの名前の扱い」） |
| 401 | `unauthorized` | 合言葉が無い・違う |
| 404 | `not_found` | 入口が違う |
| 405 | `method_not_allowed` | `POST` 以外 |
| 502 | `upstream_failed` | Jev（Workers AI）の呼び出しに失敗した・答えが読めなかった |

- `message` は人が読むための短い英文
- アプリは `code` を見ない。どれも「失敗」として扱う（ログには出してよい）
- **Jev が失敗したときは、200 の「提案なし」ではなく、必ず 502 を返す**。200 で返すと、アプリが問い合わせ済みにして、二度と問い合わせないため

例：

```json
{ "error": { "code": "bad_request", "message": "labels must have 1 to 20 items" } }
```

```json
{ "error": { "code": "unauthorized", "message": "missing or invalid token" } }
```

```json
{ "error": { "code": "upstream_failed", "message": "model call failed" } }
```

## 呼び出しの例

`curl` で `/suggest` を呼ぶ。URL と合言葉は自分の値に置き換える。

```sh
curl -X POST https://<worker>.workers.dev/suggest \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <合言葉>" \
  -d '{"labels":[{"name":"ramen","confidence":0.62},{"name":"soup","confidence":0.12}]}'
```
