# 実装計画: Cloudflare Worker で Jev を呼び、ジャンルとタグの提案を返す

## 概要

`server/` に Cloudflare Worker（中継サーバー）を作る。`POST /suggest` で Vision のラベルを受け取り、Workers AI の Jev（`env.AI.run('typesafe/jev', …)`）にジャンル・大分類・系統を選ばせ、料理のタグは対応表で決めて、`docs/suggestion-api.md` の形で返す。対応する Issue：#80。対応する機能：機能26（ジャンルとタグの提案）。呼ぶ経路は、下の「変更（2026-09-26 夕方）」の節のとおり Vercel AI Gateway に変えた（ADR 0007）。

受け渡しの形は `docs/suggestion-api.md`、理由と構成は `docs/adr/0006-suggestion-vision-jev.md`、タグと Vision のラベルの対応表は `docs/data-model.md`「タグの値」。この計画では、それらを繰り返さず、Worker の中身（ファイル・Jev への質問の組み立て・しきい値・確認手順）だけを書く。

## 前提・確認事項

- 書き方は ADR 0006 のとおり：TypeScript、Workers 標準の `export default { fetch }`、実行時のライブラリなし。開発とデプロイの道具は `wrangler`（Node.js 24 と wrangler 4 が Mac に入っていて、`wrangler whoami` でこうせいのアカウントにログイン済みなのを 9/26 に確認）
- `POST /search`（機能28）はこの Issue では作らない（#85）。`/search` は今は 404 `not_found` を返す
- Jev の呼び方（Cloudflare のモデルページと TypeSafe の quickstart。9/26 に確認）
  - 入力：`{ state: string | object, questions: { [id]: { type: 'noul' | 'choice' | 'score', instructions: string, criteria } } }`。`choice` の `criteria` は「選択肢のキー → 説明」のオブジェクト。`noul` は真偽の確率を返す質問で `criteria` は要らない。複数の質問を 1 回の呼び出しに入れられる
  - 出力：`answers[id]` に `choice`（選ばれたキー）・`confidence`（0〜1）・`probabilities`（キーごとの確率）。`usage` にトークン数
  - 上限：state と質問で 32k トークン（今回は数百トークン）。データの保持：モデルページに「Zero data retention」の記載
- Jev には確信度の数値を渡さない（ADR 0006）。Worker が「強い・弱い」に分け、文で渡す
- 決めたこと（2026-09-26。この計画を書くときの前提。変えるなら先にこの節を直す）
  - **Jev に聞くのは 3 問だけ：ジャンル・大分類・系統。それぞれ `choice` で、選択肢に「該当なし」を足す。** 料理のタグは Jev に聞かず、対応表とラベルの確信度で決める（下の「提案の決め方」）。理由：料理名は Vision のラベルが直接出るので Jev の出番が無く、Jev が得意なのは弱いラベルの組み合わせから「麺類」「中華」を推すところ（ADR 0006 の理由）
  - **しきい値は `server/src/tags.ts` の定数にまとめ、最初は仮の値で入れて `wrangler dev` で試して直す。** 決めた値と試した例は PR に書く
  - **合言葉は Worker の secret `SUGGEST_TOKEN`。** 手元は `server/.dev.vars`、本番は `wrangler secret put`
  - **Worker の名前は `kouiunodeiindayo-suggest`。** URL は `https://kouiunodeiindayo-suggest.<アカウント名>.workers.dev`（デプロイして出た URL を、#82 の `Config/Local.xcconfig` に書く）
  - **（実装で足したこと）Jev への `state` に「食べ物でないこともある」の 1 行を入れる**（`The photo may or may not show food or drink.`）。下の「リスク」の「なんでも食べ物に寄る」への先回り。強い・弱いが 0 個の行は `(none)` と書く
  - **（実装で足したこと）合言葉の比較は、両方を SHA-256 にしてから `timingSafeEqual` で比べる。** ステップ 9 の「長さを揃える」のやり方。Worker の secret が空のときは、すべて 401 にする
  - **しきい値（2026-09-26 夕方に Vercel AI Gateway 経由で 7 例を流して決定）：`LABEL_MIN` 0.05 ／ `STRONG_MIN` 0.30 ／ `DISH_LABEL_MIN` 0.10（のちに 0.30 へ上げた。この項の最後）／ `GENRE_MIN` 0.50 ／ `TAG_MIN` 0.50。仮の値のまま採用。** 根拠：Jev の `probabilities[choice]` は偏りが強く、正しい答えは 0.87〜1.0、迷うときは `none` 側に寄る（うどんの cuisine が none 0.56）。0.5〜0.85 のどこに置いても 7 例の結果は同じなので、「残り全部より高い」意味の 0.5 にした。うどん（最大 0.22 で全部「弱い」）でも food 0.97・noodles 0.87 を返したので `STRONG_MIN` 0.30 のままでよい。料理名のラベルは 0.55 以上で `DISH_LABEL_MIN` は効いていない（実機の分布は #82 で見る）。7 例の結果：

    | 例 | genre | tags | Jev の probabilities[choice]（genre／category／cuisine） |
    |---|---|---|---|
    | うどん（弱いだけ） | food | noodles | food 0.97／noodles 0.87／none 0.56 |
    | 天ぷら | food | tempura, fried, japanese | food 1.0／fried 1.0／japanese 1.0 |
    | 唐揚げ | food | karaage, fried | food 1.0／fried 1.0／none 0.83 |
    | コーヒー | drink | coffee | drink 1.0／none 1.0／none 0.97 |
    | ケーキ | dessert | cake | dessert 1.0／none 1.0／none 0.82 |
    | 食べ物でない | null | （なし） | other 1.0／none 1.0／none 1.0 |
    | ラーメン（`Soup!` 混じり） | food | ramen, noodles, chinese, japanese | food 1.0／noodles 1.0／japanese 1.0 |

    ラーメンの系統は、対応表（`chinese`）と Jev（`japanese`）の両方が付く（和集合の決まりどおり）。どちらかに寄せるかは #82 で実機の様子を見て決める

    **（2026-09-27）`DISH_LABEL_MIN` を 0.10 → 0.30 に上げた。** 実機と同じ Vision（Mac）に無料素材 6 枚を掛けると、写っていない料理名が 0.1〜0.2 で出た（うどんに ramen 0.14・spaghetti 0.11、天ぷらに fried_chicken 0.13）。正しい料理名は 0.5 以上が多い（弁当の sushi 0.70）。0.30 にすると、うどんの ramen・pasta（と、そこから付く noodles・chinese・western）と、天ぷらの karaage・fried が消え、弁当の sushi・rice_dish・japanese は残る。ラベルは `server/scripts/real-labels.tsv`、Worker に流すのは `server/scripts/try-real-labels.sh`
  - **時間切れ `TIMEOUT_MS` は 1200 ms のまま（2026-09-26 夕方）。** 手元（`wrangler dev`）で測った所要時間は 0.3〜0.9 秒（curl の `time_total`。18 回）。ただし起動直後の最初の 1 回は 1.2 秒を超えて時間切れになった（下の「リスク」）
  - **Vercel が 503（`Service temporarily unavailable`）を返したときだけ、Worker で 1 回だけ再試行する（2026-09-26 夜。こうせいの決定）。** 全体の締め切りは `TIMEOUT_MS`（1200 ms）に固定し、1 回目も 2 回目も残り時間で `AbortSignal.timeout` を作る。2 回目を送るのは残り 300 ms 以上あるときだけで、間は置かない。2 回目も 503 なら 502。503 以外の 4xx/5xx・時間切れ・ネットワークエラーは再試行しない（503 は 0.3 秒で返る一時的な失敗で、手元の実測 18 回中 6 回・本番 7 回中 1 回。他は送り直しても同じ結果か、時間を食う）。効果の目安：再試行を入れて 7 例を 2 周流したら 14 回中 200 が 6 回・502 が 8 回だったが、502 の多くは 503 ではなく 429（上の「リスク」）で、この再試行の対象外。503 だけの効果は、この計測では分からない
  - **ログに本文を出さない。** `wrangler.jsonc` に `observability` を書かない（Workers Logs を有効にしない）。`console.error` に出すのは、エラーの種類と Workers AI の例外のメッセージだけ。ラベル・Jev の答えは出さない
- 用語
  - **binding**：Worker から Cloudflare のサービス（ここでは Workers AI）を `env.AI` のように変数として使えるようにする設定。鍵は要らない
  - **secret**：Cloudflare 側に置く秘密の値。コードにも git にも入れない。Worker からは `env.SUGGEST_TOKEN` で読む
  - **`.dev.vars`**：`wrangler dev` のときだけ secret の代わりに読まれるファイル。git に入れない

## 提案の決め方（Worker の中の処理）

`docs/suggestion-api.md` の「送る」を受け取ってから「返る」を作るまで。しきい値の初期値は仮。

1. **ラベルを選別する**
   - 形に合わない `name`（英小文字・数字・`_` 以外を含む、64 文字超）は捨てる（`suggestion-api.md`「ラベルの名前の扱い」）
   - `confidence < LABEL_MIN`（仮 0.05）のラベルは捨てる（雑多なラベルを Jev に見せない）
   - 残りが 0 個なら、Jev を呼ばずに `{ "genre": null, "tags": [] }` を 200 で返す
2. **強い・弱いに分ける**：`confidence >= STRONG_MIN`（仮 0.30）を「強い」、それ以外を「弱い」
3. **Jev に 3 問を 1 回で聞く**
   - `state`（英文。数値は入れない）：
     ```
     Labels detected in a photo by an on-device image classifier (Apple Vision).
     Strong labels are likely correct. Weak labels are only hints.
     strong: ramen, noodles
     weak: soup, chopsticks, bowl
     ```
   - `genre`：`choice`。選択肢 `food`（a meal or dish）／`drink`（a beverage such as coffee, tea, beer, juice）／`dessert`（a sweet such as cake, ice cream, pastry）／`other`（not food or drink, or cannot tell）
   - `category`：`choice`。選択肢は大分類 9 つ（`noodles`…`soup`。説明は英語で一言）＋ `none`
   - `cuisine`：`choice`。選択肢は系統 5 つ（`japanese`…`ethnic`）＋ `none`
   - 質問文（`instructions`）は「What kind of …, judging from the labels」のような短い英文。文面は `jev.ts` に置く
4. **答えを読む**
   - `genre`：`choice` が `other` か `confidence < GENRE_MIN`（仮 0.50）なら `null`
   - `category`・`cuisine`：`choice` が `none` か `confidence < TAG_MIN`（仮 0.50）なら足さない
   - `answers` の形が想定と違う（キーが無い・`choice` が選択肢に無い）ときは 502 `upstream_failed`（200 の提案なしにしない。`suggestion-api.md`「エラー」）
5. **料理のタグを対応表で決める**：`docs/data-model.md`「タグの値」の表のとおり。対応する Vision のラベルのどれかが、`confidence >= DISH_LABEL_MIN`（仮 0.10）で届いたときだけ付ける。付いた料理のタグの大分類・系統（表の右 2 列）も足す
6. **まとめて返す**：`tags` は「料理のタグ」＋「表から決まる大分類・系統」＋「Jev の大分類・系統」の和集合。重複なし。並びは 料理 → 大分類 → 系統。`genre` が `null` でも `tags` は返す

## ステップ

1. `.gitignore`（リポジトリ直下）— `server/` の生成物を足す
   - `server/node_modules/`、`server/.wrangler/`、`server/.dev.vars`、`server/worker-configuration.d.ts`（`wrangler types` が作る型の定義ファイル）
2. `server/package.json`（新規）— `private: true`。`scripts`：`dev`（`wrangler dev`）、`deploy`（`wrangler deploy`）、`types`（`wrangler types`）、`check`（`tsc --noEmit`）。`devDependencies` は `wrangler` と `typescript` だけ。`dependencies` は無し（ADR 0006）
   - `npm install` して `package-lock.json` も入れる（`server/package-lock.json` はコミットする）
3. `server/wrangler.jsonc`（新規）— LP リポの `wrangler.jsonc` と同じ流儀（先頭コメント・`$schema`）。`name: "kouiunodeiindayo-suggest"`、`main: "src/index.ts"`、`compatibility_date` は作った日、`ai: { binding: "AI" }`。`observability` は書かない（上の「決めたこと」）
4. `server/tsconfig.json`（新規）— `strict: true`、`target`/`module` は `ES2022`/`ESNext`、`moduleResolution: "Bundler"`、`types: ["./worker-configuration.d.ts"]`、`noEmit: true`。`include: ["src"]`
5. `server/.dev.vars.example`（新規）— `SUGGEST_TOKEN=change-me` の 1 行と、コピーして `.dev.vars` にする旨のコメント
6. `server/src/tags.ts`（新規）— 表としきい値
   - `DISH_TAGS`：`docs/data-model.md`「タグの値」の料理の表をそのまま写した配列（`key`・`labels`・`category`・`cuisine`）。表を変えたら data-model.md も直す旨をコメントに書く
   - `CATEGORIES`（9 つ）・`CUISINES`（5 つ）：キーと、Jev に見せる英語の一言説明
   - しきい値：`LABEL_MIN`、`STRONG_MIN`、`DISH_LABEL_MIN`、`GENRE_MIN`、`TAG_MIN`。それぞれ「何のしきい値か・どう決めたか」を 1 行コメント
7. `server/src/jev.ts`（新規）— Jev とのやり取りだけ
   - 入力・出力の型（`JevRequest`・`JevResponse`。上の「前提」の形）。`worker-configuration.d.ts` の `Ai` 型に `typesafe/jev` が無ければ、この 2 つの型で `env.AI.run` の結果を受ける
   - `buildState(strong: string[], weak: string[]): string`、`buildQuestions()`、`askJev(ai, state): Promise<{ genre, category, cuisine }>`。`choice` が選択肢に無い・`answers` が欠けているときは `throw`（呼ぶ側で 502 にする）
8. `server/src/suggest.ts`（新規）— `/suggest` の本体
   - 本文の検証（`suggestion-api.md`「ラベルの名前の扱い」と「エラー」の 400 の条件）。合わないラベルは捨て、構造が違うときだけ 400
   - 上の「提案の決め方」1〜6。返す JSON は `{ genre, tags }` だけ
9. `server/src/index.ts`（新規）— 入口
   - `export default { async fetch(request, env) }`。`env` の型は `{ AI: Ai; SUGGEST_TOKEN: string }`
   - 順番：パスが `/suggest` 以外 → 404 ／ `POST` 以外 → 405 ／ `Authorization: Bearer <合言葉>` が無い・違う → 401 ／ JSON が読めない → 400 ／ `suggest()` ／ Jev の例外 → 502
   - 合言葉の比較は、長さを揃えてから `crypto.subtle.timingSafeEqual` で行う（Workers で使える。比較にかかる時間から合言葉を推測されないため）
   - エラーの JSON（`{ error: { code, message } }`）を作る小さな関数をここに置く。`Content-Type: application/json` を必ず付ける
   - `console.error` はエラーの種類と例外のメッセージだけ。リクエストの本文・ラベル・Jev の答えを出さない
10. `server/scripts/try-suggest.sh`（新規）— `wrangler dev` に向けて `curl` を投げる確認用スクリプト。URL と合言葉は環境変数（`SUGGEST_URL`・`SUGGEST_TOKEN`）で受ける。Issue の例をそのまま入れる：うどん（`noodles` `soup` `bowl` `chopsticks` が弱い）、天ぷら（`tempura` 強い）、唐揚げ（`fried_chicken`）、コーヒー（`coffee`）、ケーキ（`cake`）、食べ物でない（`desk` `keyboard`）、ラベル 0 個（400）、合言葉なし（401）、`GET`（405）、`/search`（404）
11. `docs/setup.md` — 「7. Worker（中継サーバー）」の節を足す：`cd server && npm install` → `cp .dev.vars.example .dev.vars` と合言葉の決め方（長いランダムな文字列。`openssl rand -base64 32` など）→ `npm run types` → `npm run dev` → `scripts/try-suggest.sh` で叩く → 本番は `wrangler secret put SUGGEST_TOKEN` と `npm run deploy`。Cloudflare のアカウントはこうせいのもので、デプロイもこうせいが手で行う旨。「1. 必要なもの」に Node.js の行がすでにあるので、そこに「Worker を動かす場合も」を足す
12. `docs/rules/verification.md` — 「5. Worker の確認」を足す：`cd server && npm run check`（型の確認）→ `npm run dev` → `scripts/try-suggest.sh` で 200／400／401／404／405 と提案の中身を見る。報告の形に「Worker: ✅ / ❌ ／ 触っていない」を 1 行足す
13. `docs/suggestion-api.md` — 実装して形が変わったところがあれば直す（`suggestion-api.md` の冒頭の決まり）。変えなければ触らない。しきい値の初期値は API の約束ではないので書かない
14. 検証：下の「完成の確認方法」

## 変更（2026-09-26 夕方）：Jev の呼び先を Vercel AI Gateway に変える（ADR 0007）

Workers AI の Jev はクレジットの決済が通らず呼べなかった（上の「決めたこと」の 3 つ目の「実装で足したこと」）。ADR 0007 のとおり、呼ぶ経路だけを Vercel AI Gateway の HTTP API に変える。上のステップと「提案の決め方」は、次の点だけ読み替える。

- `server/src/jev.ts` — `env.AI.run` をやめ、`fetch` で `POST https://ai-gateway.vercel.sh/v1/evaluate` を呼ぶ
  - ヘッダ：`Authorization: Bearer ${env.AI_GATEWAY_API_KEY}`、`Content-Type: application/json`
  - 本文：`{ model: "typesafe-ai/jev", state, questions }`。`state`・`questions` は今のまま（`choice` の `criteria` は「キー → 説明」で同じ）
  - 時間切れ：`AbortSignal.timeout(1200)` を付ける（アプリの 1.5 秒より先に切って 502 にする）
  - 答え：`answers[id]` は `{ type: "choice", choice, probabilities }`。`confidence` は無いので、`probabilities[choice]` を `JevAnswer.confidence` に入れる（`probabilities` が無い・数値でないときは throw → 502）。`choice` が選択肢に無いときの throw は今のまま
  - HTTP が 200 以外のときは、状態コードと `error.message`（あれば）だけを `Error` に入れて throw。本文（ラベル）は入れない
  - `askJev(apiKey: string, state: string)` に変える（`Ai` 型は使わない）
- `server/src/index.ts` — `Env` を `{ SUGGEST_TOKEN: string; AI_GATEWAY_API_KEY: string }` に。`AI_GATEWAY_API_KEY` が空なら、Jev を呼ぶ前に 502（`upstream_failed`。`console.error` に「key not set」）
- `server/src/suggest.ts` — `suggest(apiKey, labels)` に。しきい値の比較先は `confidence`（＝`probabilities[choice]`）のまま
- `server/wrangler.jsonc` — `ai` binding を消す。`npm run types` をやり直す（`worker-configuration.d.ts` から `AI` が消える）
- `server/.dev.vars.example` — `SUGGEST_TOKEN` だけのまま。`AI_GATEWAY_API_KEY` は **書かない**（下の「キーの扱い」）
- `server/scripts/try-suggest.sh` — 変更なし
- `docs/setup.md` の「7. Worker」 — 手順を差し替える
  - Vercel のアカウント・AI Gateway のカード登録・API キー（Budget を付ける）の作り方を 3 行で
  - **キーの扱い**：`.dev.vars` に書かない。手元は、こうせいが AI の入っていない端末で `npm run dev -- --var AI_GATEWAY_API_KEY:<キー>` と打って起動する（`wrangler dev` はシェルの環境変数を Worker に渡さず、`.dev.vars` があると `CLOUDFLARE_INCLUDE_PROCESS_ENV` も効かない。ダミーのキーで Vercel から 401 が返ることを確認済み）。先頭に半角スペースを入れると zsh の履歴に残らない。`--var` はコマンドの引数なので、同じ Mac の `ps` には見える。AI ツールはキーを読まない・ファイルに書かない
  - 本番：`npx wrangler secret put AI_GATEWAY_API_KEY`（こうせいが端末で実行）と `SUGGEST_TOKEN`、`npm run deploy`
  - Cloudflare のクレジット不足の項は消す
- `docs/rules/verification.md` の「5. Worker の確認」 — 「`npm run dev` は人が起動する（キーを `--var` で渡す）。AI は起動しない」を足す
- `.verification/80/notes.md` — データの扱いを Vercel の分に書き換える（ADR 0007「影響・注意」の出典）
- しきい値は、Vercel 経由で 7 例を流して決める。値と根拠を `tags.ts` のコメントと上の「決めたこと」に書く

## リスク

- **Vercel 側の Jev が 429（`The upstream provider is currently experiencing high demand`）を返すことがある**。2026-09-26 夜、5 回中 4 回。提供元（DigitalOcean）の混雑で、Vercel のレート制限ではない。0.2〜0.6 秒で返る。503 と違って再試行しない（下の「決めたこと」の再試行は 503 だけ）。429 も再試行の対象に入れるかは、こうせいが決める。Worker は 502 にし、アプリは次に仕分けを開いたときに問い合わせ直す（`docs/architecture.md`）
- **起動直後の最初の 1 回が遅い**。`wrangler dev` を起動して最初の呼び出しだけ 1.2 秒を超えて時間切れになった（2 回目以降は 0.3〜0.9 秒）。本番の Worker でも同じ可能性がある。アプリ側は問い合わせ直す作りなので、`TIMEOUT_MS` は上げずに 1200 のまま
- **（解決済み）Jev が無料枠で呼べないかもしれない**。Workers AI 経由はクレジットの決済が通らず、ADR 0007 で Vercel AI Gateway 経由に変えた。以下は当時の記録。`typesafe/jev` は third-party のモデルで、Workers AI の無料枠（Neurons）ではなく $ で課金される。`wrangler dev` の最初の 1 回で呼べるかを確かめ、呼べなければ Workers Paid（月 $5）を有効にしてから進める。金額は 1 回数百トークン × $0.042/100 万トークンなので、デモの間に使っても 1 円に満たない
- **`wrangler dev` でも Workers AI は本物を呼ぶ**（手元では動かない）。ネットが要り、課金もされる。試すときはスクリプトで回数を絞る
- **`worker-configuration.d.ts` の `Ai` 型に `typesafe/jev` の入出力が無いかもしれない**。無ければ `jev.ts` の型で受ける（`as` で 1 か所だけ変換し、コメントに理由を書く）。`any` にはしない
- **Vision のラベル名が対応表と一致しない**（`fried_chicken` か `fried_chicken_dish` かなど）。Worker 側で決めきれないので、#82 で実機のラベルを見て、表（`docs/data-model.md` と `tags.ts`）を両方直す。この Issue では表を data-model.md のとおりに入れる
- **Jev の答えが「なんでも食べ物」に寄る**（`other` を選ばない）。`state` の 1 行目で「食べ物でないこともある」と伝え、`GENRE_MIN` を上げて調整する。試した例を PR に残す
- **しきい値の当たりが付かない**。Jev の答えは `probabilities` も返るので、`wrangler dev` のときだけ `console.log` で見てよい。ただしコミットするコードには残さない（本文をログに出さない決まり）
- **Workers AI 側のデータの扱い**は Issue の完成の条件。Cloudflare の「Workers AI data usage」（2026-04-21 版：学習に使わない・保存は自分で R2 などを使ったときだけ）と、Jev のモデルページの「Zero data retention」を PR に URL つきで書く。third-party モデルはプロバイダの規約も対象になるので、TypeSafe の Privacy Policy も見て 1 行足す。LP のプライバシーポリシーと App Store の答えの見直しは、この Issue ではなく #86 で行う
- **`.dev.vars` や合言葉をコミットしない**。`.gitignore` を先に直してから `npm install` する（ステップ 1 が最初）

## 完成の確認方法

- `cd server && npm run check` が通る
- `npm run dev` を起動し、`SUGGEST_URL=http://localhost:8787 SUGGEST_TOKEN=<.dev.vars の値> scripts/try-suggest.sh` で
  - うどん・天ぷら・唐揚げ・コーヒー・ケーキの例で、`genre` と `tags` がそれらしく返る（例と結果の表を PR に書く。`docs/suggestion-api.md` の形になっていること）
  - 食べ物でない例で `genre` が `null`
  - 合言葉なし・違うで 401、`GET` で 405、`/search` で 404、ラベル 0 個で 400、形に合わない名前が混ざっていても 200
- `wrangler secret put SUGGEST_TOKEN` → `npm run deploy` して、本番の URL に同じスクリプトを向けて 1 例だけ通す。URL は PR に書く（合言葉は書かない）
- `git status` で `server/.dev.vars`・`server/node_modules`・`server/.wrangler` が出ないこと
- 実機での確認：要らない（アプリは触らない。Worker だけ）
