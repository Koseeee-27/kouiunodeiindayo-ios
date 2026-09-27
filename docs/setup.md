# 環境構築と、実機に入れる手順

初めての人が、clone してから自分の iPhone でアプリを動かすまでの手順。

## 用語

- **署名**：「このアプリは、この Apple ID の持ち主が作った」という印をアプリに付けること。iPhone は、署名の無いアプリを動かさない
- **Team ID**：Apple ID ごとに決まる、英数字10桁の番号。署名に使う
- **Bundle ID**：アプリを見分ける名前（例：`com.example.taro.appname`）
- **xcconfig**：Xcode のビルド設定を書いておけるテキストファイル
- **MCP**：AI ツールに外部の道具（ここではビルド）を使わせるための仕組み
- **hook**：git がコミットなどの節目に自動で実行するスクリプト。このリポジトリでは `.githooks/` に置いてある

## 1. 必要なもの

- Apple silicon の Mac（M1 以降）。macOS は最新
- Xcode 27（App Store から入れる）。2人とも同じメジャーバージョンに揃える
- iPhone（iOS 26 以上）と、つなぐケーブル
- Apple ID（無料でよい）
- Node.js 18 以上（XcodeBuildMCP を使う場合と、Worker（`server/`）を動かす場合。https://nodejs.org/ から入れるか、Homebrew なら `brew install node`）

## 2. Xcode の準備

1. Xcode を一度起動して、ライセンスに同意し、追加コンポーネント（iOS のプラットフォーム）を入れる
2. ターミナルで次を実行する。コマンドラインや AI からビルドするために要る

   ```bash
   # Xcode 本体を使うように切り替える（先に Command Line Tools だけを入れていた場合に必要）
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   # ライセンスに同意する（1 で同意済みなら不要）
   sudo xcodebuild -license accept
   ```

3. Xcode → Settings → Accounts で、自分の Apple ID を追加する
4. リポジトリのフォルダで、git の設定を1回だけ実行する。Xcode が `project.pbxproj` に書き戻す自分の Team ID を、コミットに入れないための設定（下の「3. 署名の設定」の注意を参照）と、コミット時に Swift ファイルを自動で整形する設定（`docs/rules/swift.md`）

   ```bash
   sh scripts/setup-git.sh
   ```

   コミット前に手で整形したいときは、Xcode でファイルを開いて Editor → Structure → Format File with swift-format（Ctrl + Shift + I）。設定（`.swift-format`）はリポジトリのものが使われる

## 3. 署名の設定（人ごとに1回）

無料の Apple ID では、2人が同じ Bundle ID を使うと署名が衝突する。
そのため、人ごとに違う値を、git に入れないファイル（`Config/Local.xcconfig`）に書く。

1. `Config/Local.xcconfig.example` をコピーして、`Config/Local.xcconfig` という名前にする
2. `BUNDLE_ID_PREFIX` を、自分だけの値にする（例：`com.example.taro`。英数字とドットだけ）
3. `DEVELOPMENT_TEAM` に、自分の Team ID を書く。調べ方は次のどちらか
   - 「キーチェーンアクセス」アプリを開き、「Apple Development: （自分のメールアドレス）」という証明書の詳細を見る。「部署」の欄の英数字10桁が Team ID（証明書は、一度 Xcode で実機向けにビルドしようとすると作られる）
   - Xcode でターゲットの Signing & Capabilities を開き、Team に自分を一度選ぶ → `grep DEVELOPMENT_TEAM Kouiunodeiindayo.xcodeproj/project.pbxproj` で出てくる `DEVELOPMENT_TEAM = XXXXXXXXXX` の値を控える（`git diff` には出ない。2 の git の設定が、この行を git から隠しているため）
4. Xcode を終了（Cmd+Q）して、プロジェクトを開き直す（開いたままだと、`Local.xcconfig` の変更が読み込まれないことがある）。ターゲットの Signing & Capabilities で、Team が自分の名前、Bundle Identifier が自分の値になっていれば成功

Xcode は、プロジェクトを開いて署名を解決するたびに、自分の Team ID を `project.pbxproj` に書き戻す（`Local.xcconfig` から拾った値。触らなくても起きる）。これがコミットに入ると相手の署名が通らなくなるので、2 の `scripts/setup-git.sh` で次の2つを入れている。

- ステージ時に `DEVELOPMENT_TEAM` の行を自動で取り除く git の filter（`.gitattributes`）。`git status` や `git diff` にも出ない。ディスク上のファイルには残るので、Xcode の署名はそのまま通る
- それでも混ざっていたらコミットを止める pre-commit hook（`.githooks/pre-commit`）

コミットに入っていないかは `git show HEAD:Kouiunodeiindayo.xcodeproj/project.pbxproj | grep DEVELOPMENT_TEAM` で確かめる（何も出なければよい）。

`Config/Local.xcconfig` はコミットしない（`.gitignore` 済み）。
`BUNDLE_ID_PREFIX` は一度決めたら変えない。無料の Apple ID では、新しい Bundle ID を7日間に10個までしか作れない。

## 4. 実機に入れる

1. iPhone を Mac につなぎ、iPhone 側で「このコンピュータを信頼」を選ぶ
2. iPhone の 設定 → プライバシーとセキュリティ → デベロッパモード をオンにして、再起動する
3. Xcode の上部で、実行先に自分の iPhone を選んで ▶ を押す
4. 初回は iPhone 側で、設定 → 一般 → VPN とデバイス管理 から、自分の Apple ID の開発元を信頼する（iPhone がインターネットにつながっている必要がある。会場の Wi-Fi が不安定なら、事前に済ませておく）

### 無料の Apple ID の制限

- 入れたアプリは **7日で使えなくなる**。Xcode からもう一度入れ直せば使える（データは残る）
- 1台の iPhone に入れられる自作アプリの数には上限がある（3本までとの情報。Apple の公式な記載は未確認）
- **デモ機は1台に決め、入れる人も1人に決める**。Bundle ID が人ごとに違うので、2人が同じ iPhone に入れると別のアプリになり、データも別になる
- デモ機には、本番前日（9/25）に入れ直す

## 5. AI ツールの設定

ルールの正本は `AGENTS.md`。どのツールも、リポジトリを開くだけで読み込む。

| ツール | ルールの入口 | MCP の設定 |
|---|---|---|
| Claude Code | `CLAUDE.md`（`AGENTS.md` を取り込む） | `.mcp.json`（初回に、使ってよいかの確認が出る） |
| Codex | `AGENTS.md` を自動で読む | `.codex/config.toml`（初回起動時の確認で、このリポジトリを信頼済みにすると有効になる） |
| Antigravity | `AGENTS.md` を自動で読む。`.agents/rules/project.md` が追加のルールを取り込む。`/self-review` は `.agents/workflows/` に置いてある（この置き場所は公式の資料で確認できていない。呼び出せなければ、Antigravity の画面から workflow として登録し直す） | `.agents/mcp_config.json` |

- Codex は、ファイルの取り込み（`@`）をしない。`docs/rules/swift.md` と `docs/architecture.md` は、`AGENTS.md` の指示に従って AI が自分で読む形になる。読んでいないようなら、最初に読むよう頼む
- MCP の設定は、ツールごとに3つのファイルに同じ内容を書いている。変えるときは3つとも直す

### XcodeBuildMCP（リポジトリに設定済み）

- ビルド、シミュレータでの実行、実機へのインストール、ログの取得ができる。入れておくと、AI が自分でコンパイルエラーを直せる
- 起動のたびに最新版をインターネットから取得する。会場のネットワークが不安定だと、起動に失敗することがある
- エラー情報を開発元に送る機能は、設定でオフにしてある（`XCODEBUILDMCP_SENTRY_DISABLED=true`）
- 実機向けのツールを使うには、先に「3. 署名の設定」を済ませておく

### Xcode の MCP（人ごとに1回）

Xcode 本体が持つ連携。ビルドに加えて、**Apple の公式ドキュメントの検索**と SwiftUI プレビューの画像化ができる。Xcode 27 は新しく、AI の知識が古いことがあるので、入れておくことを勧める。

1. Xcode → Settings → Intelligence → Model Context Protocol で、「Allow external agents to use Xcode tools」にチェックを入れる
2. 使うツールに登録する

   ```bash
   # Claude Code
   claude mcp add --scope user --transport stdio xcode -- xcrun mcpbridge

   # Codex
   codex mcp add xcode -- xcrun mcpbridge
   ```

   Antigravity は、`~/.gemini/config/mcp_config.json` の `mcpServers` に、`"xcode": { "command": "xcrun", "args": ["mcpbridge"] }` を足す

3. 使うときは Xcode でプロジェクトを開いておく

## 6. 困ったとき

- ビルドは通るのに実機に入らない：署名（3）と、iPhone 側の信頼（4）を見直す
- `xcodebuild` が「requires Xcode」と言って動かない：2 の `xcode-select` を実行する
- 起動した瞬間に落ちるようになった：データの形を変えた可能性がある。アプリを削除して入れ直す（`docs/data-model.md`）
- カメラが映らない：シミュレータではカメラは動かない。実機で確認する
- 効果音が鳴らない：iPhone がマナーモードになっていないか、アプリの設定の「効果音の音量」がいちばん左（0）になっていないか確認する

## 7. Worker（中継サーバー）

ジャンルとタグの提案（機能26）のための Cloudflare Worker。コードは `server/`、受け渡しの形は `docs/suggestion-api.md`。
Jev は Vercel AI Gateway の HTTP API 経由で呼ぶ（理由は `docs/adr/0007`）。Cloudflare と Vercel のアカウントはこうせいのもの。本番へのデプロイも、こうせいが手で行う。

1. 道具を入れる

   ```bash
   cd server && npm install
   ```

2. 手元の合言葉を作る。`.dev.vars` は git に入れない

   ```bash
   cp .dev.vars.example .dev.vars
   openssl rand -base64 32   # 出た長いランダムな文字列を、.dev.vars の SUGGEST_TOKEN に書く
   ```

3. Vercel AI Gateway の API キーを用意する（こうせいが行う。1 回だけ）
   - Vercel のアカウントを作り、AI Gateway の画面でカードを登録する（決済ではなく有効性の確認。無料クレジット $5 が使える）
   - AI Gateway → API Keys でキーを作る。キーには Budget（使える上限）を付け、ハッカソンが終わったら無効にする
   - 使うモデルは `typesafe-ai/jev`。ダッシュボードの Models で扱われていることを確かめる

4. 型の定義を作る（`wrangler.jsonc` を変えたときもやり直す）

   ```bash
   npm run types
   ```

5. 手元で動かして、確認用のスクリプトで叩く。Jev は手元で動かしても Vercel の本物を呼ぶので、ネットが要り、クレジットを使う

   **キーの扱い**：`AI_GATEWAY_API_KEY` は `.dev.vars` に書かない。人が、AI ツールの入っていないターミナルで、`wrangler dev` の `--var` で渡して起動する（`wrangler dev` はシェルの環境変数を Worker に渡さない。`.dev.vars` があると `CLOUDFLARE_INCLUDE_PROCESS_ENV` も効かない）。行の先頭に半角スペースを入れると zsh の履歴に残らない。ただし `--var` はコマンドの引数なので、起動中は同じ Mac の `ps` には見える。AI ツールはキーを読まない・ファイルに書かない・表示しない。AI ツールが行うのは、起動済みの `localhost:8787` に `SUGGEST_TOKEN` で叩くことだけ

   ```bash
    npm run dev -- --var AI_GATEWAY_API_KEY:<キー>   # 先頭に半角スペース
   # 別のターミナルで
   SUGGEST_URL=http://localhost:8787 SUGGEST_TOKEN=<.dev.vars の値> scripts/try-suggest.sh
   ```

6. 本番に出す（こうせいが行う）

   ```bash
   npx wrangler secret put AI_GATEWAY_API_KEY   # Vercel の API キー。端末で入力する
   npx wrangler secret put SUGGEST_TOKEN        # 本番の合言葉。手元とは別の値にする
   npm run deploy
   ```

- 提案が全部 502 になる（`wrangler dev` のログに `AI_GATEWAY_API_KEY not set`）：キーを `--var` で渡さずに起動している（環境変数で渡しても届かない）。上の 5 のとおり起動し直す
- `wrangler dev` のログに `jev http 402` が出る：Vercel のクレジットが尽きている。AI Gateway の画面で残高を足す（自動チャージは初期設定でオフ）

### アプリから Worker を呼ぶ（人ごとに1回）

アプリは、Worker の URL と合言葉を `Config/Local.xcconfig`（git に入れない）から読む。書かなければ、提案が出ないだけで、撮る・仕分けるはいつもどおり動く。

1. `Config/Local.xcconfig` に2行を足す（見本は `Config/Local.xcconfig.example`）

   ```
   SUGGESTION_BASE_URL = https:/$()/<worker>.workers.dev
   SUGGESTION_TOKEN = <合言葉>
   ```

   - xcconfig では `//` 以降がコメントになる。URL の `//` は `$()`（空の値）で区切って `https:/$()/…` と書く。末尾に `/` は付けない
   - 合言葉は、上の 6 で本番の Worker に `wrangler secret put SUGGEST_TOKEN` で入れた値。手元の `wrangler dev` を呼ぶときは、URL を `http:/$()/localhost:8787`、合言葉を `.dev.vars` の値にする（実機からは Mac の `localhost` に届かないので、シミュレータだけ）
2. Xcode を終了（Cmd+Q）して開き直す
3. ターゲット `Kouiunodeiindayo` → Build Settings（All・Combined）で「Info.plist File」を検索し、`Config/Info.plist` が細字で出ていることを見る。太字なら、その行を選んで Delete キーで消す（ターゲット側の値が xcconfig より優先されるため）
4. Product → Clean Build Folder（Shift+Cmd+K）のあと、ビルドし直す

仕組み：`Config/Base.xcconfig` が `INFOPLIST_FILE = Config/Info.plist` を指定し、`Config/Info.plist` の `$(SUGGESTION_BASE_URL)`・`$(SUGGESTION_TOKEN)` がビルド時に `Local.xcconfig` の値に置き換わる。アプリは `Bundle.main` から読む。独自のキーは `INFOPLIST_KEY_〜` では入れられないため、この形にしている。ターゲットの Info タブでキーを足さない（`project.pbxproj` に書き戻される）。

- 合言葉はアプリの中（Info.plist）に入るので、抜き取れる。デモの間だけの簡易的な対策（`docs/adr/0006-suggestion-vision-jev.md`）。ハッカソンが終わったら、Worker の `SUGGEST_TOKEN` を変える
- 提案が保存されたかは、Xcode のコンソールで `SuggestionService` のログを見る。URL・合言葉は、ログにもコミットにも出さない

## 付録：プロジェクトを作る人が、最初に1回だけやること

Xcode でプロジェクトを新規作成した直後は、Bundle ID と Team ID がプロジェクトファイル（`project.pbxproj`）のターゲット側に書かれている。ターゲット側の値は xcconfig より優先されるので、そのままでは `Config/Local.xcconfig` が効かない。

1. Xcode で新規プロジェクトを作る（Choose Template… → iOS → App。Interface は SwiftUI、Storage は SwiftData）。Product Name は `Kouiunodeiindayo`。保存先はこのリポジトリのフォルダ
   - 「Create Git repository on my Mac」のチェックは外す。作成後、`Kouiunodeiindayo/` の中に `.git` ができていたら消す（リポジトリの中に別のリポジトリができてしまうため）
   - Xcode は保存先に `Kouiunodeiindayo/` を1段作るので、Xcode を終了（Cmd+Q）してから、その中の `Kouiunodeiindayo.xcodeproj` と `Kouiunodeiindayo/` をリポジトリの直下へ移し、空になったフォルダを消す
   - Bundle ID は `Config/Base.xcconfig` に小文字で書いてあり、Product Name を変えても変わらない
2. `Config` フォルダをプロジェクトに追加する（File → Add Files to "Kouiunodeiindayo"…。Targets のチェックは外し、コピーはしない）。追加しないと、次の手順で `Base` を選べない
3. 左の一覧でプロジェクト（青いアイコン）を選び、PROJECT の `Kouiunodeiindayo` → Info → Configurations で、Debug と Release それぞれのプロジェクトの行に `Base` を割り当てる
4. Build Settings（All・Combined）で、次の太字の行を選んで Delete キーで消す（細字になれば、xcconfig の値が使われている）。消す場所が PROJECT と TARGETS に分かれている
   - PROJECT の `Kouiunodeiindayo`：iOS Deployment Target
   - TARGETS の `Kouiunodeiindayo`：Product Bundle Identifier、Targeted Device Families。Supported Interface Orientations（画面の向き）は消さない（Xcode が開くたびに書き戻すので、pbxproj 側に持たせている）
   - Development Team は、PROJECT と TARGETS の両方を見て、太字なら消す
5. Signing & Capabilities で「Automatically manage signing」はオンのまま。Team のプルダウンは触らない（選ぶと、Team ID がプロジェクトファイルに書き戻される）
6. 自分の `Config/Local.xcconfig` を作り（上の 3）、実機でビルドできることを確かめてからコミットする。コミット後に `git show HEAD:Kouiunodeiindayo.xcodeproj/project.pbxproj | grep DEVELOPMENT_TEAM` で、何も出ないことを確かめる
7. 終わったら、この付録は残しておく（テスト用のターゲットを足したときも、同じ作業が要る）
