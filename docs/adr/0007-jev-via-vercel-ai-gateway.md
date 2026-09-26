# 0007: Jev は Cloudflare Workers AI ではなく、Vercel AI Gateway の HTTP API 経由で呼ぶ

- 状態：採用
- 日付：2026-09-26

## 決めたこと

- 0006 の構成（端末の Vision → Cloudflare Worker → Jev）は変えない。変えるのは **Worker から Jev を呼ぶ経路だけ**
- Worker は Workers AI の binding（`env.AI.run('typesafe/jev', …)`）をやめ、Vercel AI Gateway の評価 API を `fetch` で呼ぶ：`POST https://ai-gateway.vercel.sh/v1/evaluate`、本文は `{ model: "typesafe-ai/jev", state, questions }`、ヘッダは `Authorization: Bearer <AI Gateway の API キー>`。ライブラリ（AI SDK）は使わない
- 質問の形は 0006 のまま（`state` は英文、`questions` は `choice` で「選択肢のキー → 英語の説明」）。答えは `answers[id].choice` と `probabilities`。`confidence` は返らないので、選ばれたキーの `probabilities` の値をしきい値に使う
- API キーは Worker の secret `AI_GATEWAY_API_KEY` に置く。手元の `wrangler dev` は、こうせいがキーを環境変数で渡して自分の端末で起動する。AI ツールはキーを読まない・ファイルに書かない。Vercel 側でキーに Budget（使える上限）を付け、ハッカソン後に無効化する
- `wrangler.jsonc` の `ai` binding は外す。Cloudflare 側の課金は Worker の無料枠だけになる

## 理由

- Workers AI の Jev は他社（TypeSafe）のモデルで、Cloudflare の AI Gateway の前払いクレジットからしか払えない（2026-08 から）。2026-09-26 にチャージを 7 回試したが、カード決済がすべて失敗した（3D セキュアの後にカード会社側で拒否。カードを変えても同じ）。理由はカード会社にしか分からず、本番（9/27）に間に合わない
- TypeSafe の API を直接使う道は waitlist（順番待ち）で、今日は使えない
- Vercel AI Gateway は Jev を扱っていて、公式の HTTP API（`/v1/evaluate`）がある。カードの登録（決済ではなく有効性の確認）が通り、$5 の無料クレジットが使える状態になった。前払い方式で、残高が尽きたら `402` で止まるだけ。自動チャージは初期設定でオフ。Jev は 1 回 300 トークンほど（約 $0.00001）なので、ハッカソンで使い切ることはない
- 質問と答えの形が Workers AI 経由とほぼ同じなので、差し替えは Jev を呼ぶ 1 ファイルで済む。アプリと受け渡しの形（`docs/suggestion-api.md`）は変わらない

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| Cloudflare の決済が通るのを待つ | 原因が分からず、いつ通るか読めない。通ったら 0006 の形に戻せる（`jev.ts` の差し替えだけ） |
| TypeSafe の API を直接呼ぶ | waitlist で今日は使えない |
| DigitalOcean Gradient 経由 | Jev はあるが前払い残高が必須で、決済の壁は同じ。呼び方（評価モデルの API）も未確認 |
| Workers AI の Llama（無料枠）に替える | 決済は要らないが、Jev の「選択肢から選ぶだけ・速い・確率つき」を失い、JSON モードの調整と時間切れの緩和（1.5 秒 → 3 秒）が要る。Vercel がだめだったときの退路として残す |
| Vercel の AI SDK（`ai`・`@ai-sdk/gateway`）で呼ぶ | 実行時のライブラリを足すことになる（`AGENTS.md`）。公式の HTTP API で足りる |

## 影響・注意

- `/v1/evaluate` の答えには `confidence` が無い。`probabilities[choice]` を代わりに使うので、しきい値の値は試して決め直す
- Vercel 上の Jev の直近 1 日の稼働率は 95% ほど（2026-09-26 時点。提供元は DigitalOcean）。失敗したときは 0006 のとおり 502 を返し、アプリは次に仕分けの画面を開いたときにもう一度問い合わせる
- データの扱い：Vercel は本文（質問と答え）を保持せず、学習にも使わないと明記。モデルの情報では `no_training: all`、`zdr: none`（提供元でのゼロ保持の約束は無い）。Worker が送るのはラベルの英単語だけ。プライバシーポリシーと App Store の答えの見直しは #86
- 無料クレジットは月ごと。購入したクレジットは 1 年で失効。Budget をキーに付けておけば、漏れても上限で止まる
- 手元の確認手順が変わる：`wrangler dev` は AI ではなく人が起動する（`docs/setup.md`）。AI は `localhost` に `SUGGEST_TOKEN` で叩くだけ
- Cloudflare 側に未払いのチャージの請求書が 7 枚残っている。あとで自動で決済されて二重に引かれたら、Cloudflare のサポートに取り消しを頼む

## 出典

- https://vercel.com/docs/ai-gateway/modalities/evaluation （HTTP API・質問の形・答えの形）
- https://vercel.com/docs/ai-gateway/pricing （無料枠・前払い・自動チャージ）
- https://vercel.com/docs/ai-gateway/faq （カード登録が要ること・データの扱い）
- https://ai-gateway.vercel.sh/v1/models （`typesafe-ai/jev` の情報。`no_training`・`zdr`・価格）
- https://developers.cloudflare.com/changelog/post/2026-08-07-workers-ai-unified-billing/ （Workers AI の外部モデルが前払いクレジットになった変更）
- https://developers.cloudflare.com/ai-gateway/features/unified-billing/ （クレジットのチャージ手順）
