# 0006: ジャンルとタグの提案は、端末の Vision と、Cloudflare Worker 経由の Jev で作る

- 状態：採用
- 日付：2026-09-26

## 決めたこと

- 写真から「写っているもの」を取り出すのは、端末の中の Vision（`ClassifyImageRequest`。iPhone 標準の画像分類。1303 種類のラベルと確信度を返す）で行う
- 取り出したラベル（文字）を、TypeSafe AI の Jev（決まった選択肢から選び、確率付きで答える AI。文章は作らない）に渡し、ジャンル・タグを選ばせる。言葉で探す（機能28）も、検索の言葉を Jev に渡して、絞り込みの条件を選ばせる
- Jev は Cloudflare Workers AI（モデル名 `typesafe/jev`）で呼ぶ。アプリは Jev を直接呼ばず、自分たちの Cloudflare Worker（中継サーバー）1本を経由する。Worker のコードはこのリポジトリの `server/` に置く
- Worker は TypeScript で、Workers 標準の書き方（`export default { fetch }`）で書く。ライブラリ（Hono など）は使わない。Workers AI は binding（`env.AI.run`）で呼ぶので、鍵を Worker に置く必要もない。開発とデプロイは `wrangler`（Node.js と npm で動く）。本番は Cloudflare の実行環境で動くので、Node・Deno・Bun の API には頼らない
- 質問の文面・タグの選択肢・しきい値は Worker 側に置く。アプリから送れるのはラベルと検索の言葉だけにする
- 外に送るのは、ラベルの名前と検索の言葉だけ。写真と記録は送らない。Worker は受け取った内容を保存しない
- 通信できない・時間切れ・自信が低いときは、提案を出さないだけにする。仕分けと記録はいつも通りできる

記録の保存先（端末内。0002）は変えない。Worker は記録を持たない。

## 理由

- Vision は端末の中で動き、1枚数十 ms で終わる（M4 の Mac で 6〜10ms。iPhone でもこの数倍と見込む）。iOS 26 以上のどの iPhone でも使える
- Vision のラベルはそのままでは雑多（机・食器も混ざる）で、和食の料理名はよく外れる。複数の弱いラベル（`chopsticks`・`soup`・`ramen` が弱く出る → 麺類）をまとめて判断させるところに、Jev が向いている
- Jev は選択肢から選ぶだけなので、変な文章やキャラ崩れが出ない。応答は 70〜500ms と速く、料金は入力 100 万トークンで $0.042（出力は無料）
- Cloudflare Workers AI 経由なら、TypeSafe の API キーを持たずに Worker から呼べる。LP ですでに Cloudflare を使っているので、新しいサービスへの登録が要らない
- API キーをアプリに入れると抜き取られる。中継を挟めば、鍵は Worker 側だけに置ける

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| Vision のラベルだけ（対応表で決める） | 一番簡単だが、複数の弱いラベルからの判断（麺類など）ができない |
| Foundation Models の画像入力（iOS 27） | 画像を直接見られて和食に強い見込み。ただし iPhone 15 Pro 以降だけで、回答に数秒かかる |
| Cloudflare Workers AI の画像対応 LLM（Llama 4 Scout など） | 写真そのものを外に送ることになる。回答に数秒かかる |
| 日本食の写真で自前のモデルを学習する（UEC FOOD-256 など） | 学習に時間がかかる。写真集は研究目的の利用に限られる |
| アプリから Workers AI の REST API を直接呼ぶ | Cloudflare の API トークンをアプリに入れることになり、抜き取られると他のモデルも使われる。質問の中身もアプリから自由に変えられてしまう |
| Worker を Hono で書く | ルーティングや合言葉のチェックが短く書けるが、入口は2本（`/suggest`・`/search`）だけで、標準の書き方で足りる。ライブラリが1つ増える |
| Worker を別のリポジトリに置く | ルールとテンプレを一から作る手間がかかり、受け渡しの形を2か所で管理することになる。大きくなったら分ける |
| TypeSafe の API や Vercel AI Gateway を直接使う | 使えるが、鍵の管理とサービスの登録が増える。Vercel は無料枠でもカードの登録が要り、回数の制限がきつい |

## 影響・注意

- `AGENTS.md` の「サーバー無し」の前提が変わる。記録は端末内のままで、提案のためだけに通信する
- アプリから Worker を呼ぶための URL と合言葉は、git に入れない `Config/Local.xcconfig` に書く。Info.plist への取り込みはビルド設定の変更なので、人が Xcode で行う
- 合言葉はアプリの中に入るので、抜き取れる。ハッカソンのデモの間だけ使う前提の簡易的な対策。App Store に出すなら、App Attest（本物のアプリからの通信かを確かめる Apple の仕組み）などを別の ADR で検討する
- Jev は英語が主な学習言語。質問と選択肢は英語のキー（`ramen` など）で書き、画面に出すときに日本語にする。数値の比較が苦手なので、ラベルの確信度は数値のまま渡さず「強い・弱い」の言葉にする
- 料理のタグは、Vision のラベルで裏付けが取れるものだけを提案する（タグとラベルの対応は `docs/data-model.md`）
- 文字認識（`RecognizeTextRequest`）は、初回に日本語のモデルの読み込みで十数秒かかることがあった（Mac で確認）。使うなら先に1回動かしておく
- Workers AI の制限（Jev は毎分 1,200 リクエストなど）は、予告なく変わることがある
- Workers AI 側でのデータの扱い（保存・学習への利用）は、公開前に Cloudflare の規約で確かめる。プライバシーポリシーと App Store の答えも、この決定に合わせて直す
- Vision の処理はメインスレッドの外で動かし、結果の保存だけをメインスレッドで `RecordStore` を通して行う（SwiftData の決まりは `docs/rules/swift.md`）

## 出典

- https://developers.cloudflare.com/ai/models/typesafe/jev/
- https://typesafe.ai/blog/introducing-system-one-models-and-jev
- https://docs.typesafe.ai/introduction/quickstart
- https://docs.typesafe.ai/models
- https://developer.apple.com/documentation/vision/vnclassifyimagerequest
- https://developer.apple.com/videos/play/wwdc2026/241/
- http://foodcam.mobi/dataset256.html
