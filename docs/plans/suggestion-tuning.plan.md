# 実装計画: Worker の提案で、料理のタグを 1 つに絞り、ジャンルとの食い違いを除き、おまかせを根拠の強い写真だけにする

## 概要

Worker（`server/src/`）の提案の決め方を 3 つ直し、あわせて本番で「決まって 502」になる 2 件の原因を切り分ける。アプリは変えない（おまかせの条件は `genreConfidence` で表す。決めたこと）。対応する Issue：#114（親 #86）。対応する機能：機能26。

1. 料理のタグは、対応するラベルのうち一番強い 1 つだけ、0.15 以上で付ける（今は 0.30 以上を全部）
2. ジャンルと食い違うタグを除く（飲み物に「ラーメン」を付けない）
3. Vision の食べ物系のラベルが弱い写真は、おまかせで飛ばさない
4. 決まって 502 になる 2 件の原因（回数の制限か、入力か）を確かめる

main から `feat/114-suggestion-tuning` を切って作る。受け渡しの形は `docs/suggestion-api.md`、Worker の元の計画は `docs/plans/suggestion-worker.plan.md`（マージ済み。書き換えない。この計画に続きを書く）。

**目安：2 時間**（Worker 1 時間・確かめる道具 30 分・ドキュメント 30 分）＋こうせいの作業（502 の切り分け 15 分・デプロイ 5 分）。Worker のデプロイだけで効き、アプリの入れ替えは要らないので、13:00 の直前でも入れられる。

## 決めたこと（2026-09-27、こうせいと確認。ideas-0927 の 5）

- 5-1：失敗の問い合わせ直しを先に（#113）。プロンプトとしきい値は計測を見るまで変えない
- 5-2：料理のタグは一番強い 1 つだけ・0.15 以上
- 5-3：おまかせの条件に「Vision の食べ物系のラベルが 0.30 以上」を足す
- 5-4：Jev の計測はこうせいが鍵を入れて行う
- （計画のときの要判断 1。2026-09-27 こうせい確認）おまかせの条件は `genreConfidence` で表す：Vision の食べ物系のラベル（`food`・`drink`・`beverage`・`dessert`・`baked_goods`）の最大が 0.30 未満のとき、ジャンルは返すが `genreConfidence` を `null` にする。アプリは今の「確率 0.8 以上なら飛ばす」のまま（`null` は飛ばない）。アプリの入れ替えが要らない
- （計画のときの要判断 2）決まって 502 の件は、こうせいの切り分け（ステップ 1）の結果で直すものを決める。入力が原因なら Worker で直す。回数の制限なら、制限の値を #113 に渡す（#113 は失敗に合わせて遅くする作りなので、値が分からなくても動く）。結果が出るまで、ステップ 2 以降は進めてよい
- （計画のときの要判断 3）前置きの 1 文と `STRONG_MIN` は、こうせいの Jev の計測（作業用のメモ `tune-0927`）の結果で決める。13:00 に間に合わなければ、この PR では変えない
- （Issue #114）ジャンルとタグの食い違いを除く：ジャンルが「飲み物」なら飲み物の料理タグ（コーヒー・お茶・お酒・ジュース・タピオカ）だけ、「デザート」ならデザートの料理タグ（ケーキ・アイス・ドーナツ・焼き菓子）だけ、「食べ物」ならそれ以外の料理タグだけ。大分類・系統は「食べ物」のときだけ。ジャンルが無いときは絞らない

## 根拠（こうせいの写真 77 枚。作業用のメモ `photos-0927`）

Mac の Vision に掛けたラベルで、Worker の決まりの部分だけを数えた（Jev は呼んでいない。分類は Vision のラベルからの仮）。

| | 今（0.30 以上を全部） | 一番強い 1 つ・0.15 |
|---|---|---|
| 料理のタグが付く写真 | 34 枚 | 46 枚 |
| タグが 2 つ以上付く写真 | 5 枚（ラーメン＋パスタ 2・パスタ＋天ぷら・ハンバーガー＋ジュース・ピザ＋焼き菓子） | 0 枚 |
| ジャンルと食い違うタグ（仮の分類で） | 2 件 | 5 件 → 食い違いを除く決まりで 0 件 |

- おまかせの条件（食べ物系 0.30 以上）：食べ物・飲み物・デザートの 66 枚中 59 枚は候補に残り、料理でない?・料理? の写真は 1 枚も通らない
- 無料素材 25 枚（`tune-0927`）の正解つきの 10 枚では、料理のタグの正しい数が 6 → 7、誤りは 2 のまま
- 麺の写真では Vision が `spaghetti` を 0.6〜0.87 で出すことがある（9 枚）。1 つに絞っても「パスタ」が残る写真がある。正誤はこうせいの確認待ち

## 作り方

### `server/src/tags.ts`

- `DishTag` に `kind: "food" | "drink" | "dessert"` を足す（coffee・tea・alcohol・juice・bubble_tea が drink、cake・ice_cream・donut・baked_sweets が dessert、ほかは food）。`docs/data-model.md` の「タグの値」の表と同じにする
- `DISH_LABEL_MIN` を 0.30 → 0.15。コメントに値と理由（上の根拠。1 つに絞ることと、食い違いを除くこととセットで下げた）
- 新しい定数 `AUTO_EVIDENCE_MIN = 0.3` と `GENERAL_FOOD_LABELS = ["food", "drink", "beverage", "dessert", "baked_goods"]`。コメントに理由

### `server/src/suggest.ts` の `suggest()`

1. ジャンル（今のまま）
2. 料理のタグ：`DISH_TAGS` ごとに、対応するラベルの確信度の最大を求め、一番大きいもの 1 つ（同じなら `DISH_TAGS` の順で先）。それが `DISH_LABEL_MIN` 以上なら付ける
3. 食い違いを除く：ジャンルがあるとき、`dish.kind !== genre` なら料理のタグを捨てる。ジャンルが `food` 以外なら、大分類・系統（料理のタグから決まるものも、Jev の答えも）を全部捨てる
4. 大分類・系統は、残った料理のタグから決まるものと、Jev の答え（ジャンルが `food` か、ジャンルが無いとき）
5. おまかせの条件（決めたこと）：`labels` の中の `GENERAL_FOOD_LABELS` の確信度の最大が `AUTO_EVIDENCE_MIN` 未満なら、`genreConfidence = null`（ジャンルは返す）
- 並び（料理 → 大分類 → 系統）と重複の除き方は今のまま

### 確かめる道具（`server/scripts/check-suggest.mjs`、新規。実行時のライブラリは足さない）

- `npx wrangler deploy --dry-run --outdir .check`（本番には送らない）で組み立てた Worker を読み、`fetch` を偽の Jev に差し替えて `/suggest` を呼ぶ（Node 24。`crypto.subtle.timingSafeEqual` は Node に無いので、比べるだけの偽物を入れる）
- 例と期待を並べて、違えば止まる：
  - ラーメン（ramen 0.62・spaghetti 0.24）＋ Jev が food → タグは `ramen` と大分類・系統。`pasta` は付かない
  - ラーメンのラベル＋ Jev が drink → 料理のタグ・大分類・系統が付かない（こうせいの指摘の再現）
  - コーヒー（coffee 0.8）＋ Jev が food → `coffee` は付かない
  - 唐揚げ弁当（fried_chicken 0.18）＋ food → `karaage`（0.15 以上）
  - 食べ物系が弱い（tableware 0.9・food 0.21）＋ food 0.97 → `genre: food`・`genreConfidence: null`
  - 食べ物系が強い（food 0.9）＋ food 0.97 → `genreConfidence: 0.97`
  - ジャンルなし（other）＋ ramen 0.62 → `ramen` は付く（絞らない）
  - 偽の Jev が 6 回目から 429 → 6 回目から 502（決まって 502 の見立ての再現）
- `package.json` の `scripts` に `"check:suggest": "wrangler deploy --dry-run --outdir .check && node scripts/check-suggest.mjs"`。`.check/` は `.gitignore` に足す

## ステップ

1. **（こうせい）決まって 502 の切り分け**。本番を叩くのは人
   1. `cd server && npx wrangler tail` を別のターミナルで開いたまま `SUGGEST_URL=… SUGGEST_TOKEN=… scripts/try-suggest.sh`。落ちた 2 件のログが `upstream_failed jev http 429` なら回数の制限。`jev http 400`・`jev choice out of options` などなら入力
   2. 回数の制限なら、Vercel のダッシュボードで AI Gateway の制限（1 分あたりの回数など）を見て、値を #113 に書く（`minInterval` を合わせる）。`try-suggest.sh` に例の間の待ち（`sleep "${SUGGEST_INTERVAL:-0}"`）を足すかはこの Issue で決める（推奨：足す。既定 0）
   3. 入力が原因なら、ログを AI に渡す（この計画に直し方を足す）
2. `server/src/tags.ts`・`server/src/suggest.ts` — 上の「作り方」。確認：`cd server && npm run check`
3. `server/scripts/check-suggest.mjs`・`package.json`・`.gitignore` — 上の「確かめる道具」。確認：`npm run check:suggest` が全部通る
4. `server/scripts/try-real-labels.sh` を手元（`wrangler dev`。鍵はこうせいが渡して起動）か、デプロイ後の本番（こうせい）で流し、変える前と後の返りを並べて PR に書く
5. ドキュメント
   - `docs/suggestion-api.md`：返る の表の `tags` に「ジャンルと食い違うタグは返さない（飲み物・デザートのときは、その種類の料理のタグだけ。大分類・系統は食べ物のときだけ）」、`genreConfidence` に「Vision の食べ物系のラベルが弱い（0.30 未満）ときは `null`（おまかせで飛ばさないため）」。「料理のタグは、対応する Vision のラベルが `labels` にあるときだけ返す」を「…ラベルのうち一番強い 1 つだけ（0.15 以上）」に
   - `docs/data-model.md` の「タグの値」：料理の表に「種類」の列（食べ物／飲み物／デザート）を足す。「料理のタグは、Vision のラベル（右の列）のどれかが出たときだけ提案する」を「…一番強い 1 つだけを提案する。ジャンルと種類が違うものは提案しない」に
   - `docs/architecture.md`：変えない（アプリの流れは同じ）
6. こうせいが本番にデプロイ（`cd server && npm run deploy`）→ `try-real-labels.sh` を本番に向けて流す
7. 前置きの 1 文・`STRONG_MIN`（決めたこと）：こうせいの計測が出たら、結果を AI に渡して値を決め、同じ PR か次の PR で直す
8. コミット `feat: 提案の料理のタグを 1 つに絞り、ジャンルとの食い違いを除く (#114)`／`feat: 食べ物系のラベルが弱い写真はおまかせで飛ばさない (#114)`／`chore: 提案の決め方を偽の Jev で確かめるスクリプトを足す (#114)`／`docs: 提案の決め方の直しを受け渡しの形とデータ設計に書く (#114)`

## リスク

- **「パスタ」の誤り**：麺の写真に Vision が `spaghetti` を強く出すと、1 つに絞っても「パスタ」になる。こうせいの写真で正誤を見て、多ければ `spaghetti` だけしきい値を上げる（別の小さな直し）
- **0.15 の弱いラベル**：料理の写真に「ケーキ」「ドーナツ」が 0.15〜0.25 で出る。食い違いの除き方で、ジャンルが食べ物なら落ちる。ジャンルが無いときは残る（決めたことどおり絞らない）
- **`genreConfidence` の意味が変わる**（決めたこと）：アプリのログの確率が `-` になる写真が増える。おまかせの枚数（「おまかせ n」）が減る。実機で見る
- **Worker をデプロイすると、既に届いた提案は変わらない**（問い合わせ直さない）。デモの写真は、デプロイのあとに取り込み直す（#103 のデモの準備と同じ）

## 完成の確認方法

- `cd server && npm run check` と `npm run check:suggest`
- 本番（こうせい）：デプロイ後に `try-real-labels.sh` と `try-suggest.sh`。決まって 502 の 2 件の原因が分かっている
- 実機（任意。こうせい）：おまかせで、食べ物系のラベルが弱い写真が飛ばないこと
