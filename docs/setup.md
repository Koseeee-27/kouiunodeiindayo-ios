# 環境構築と、実機に入れる手順

初めての人が、clone してから自分の iPhone でアプリを動かすまでの手順。

## 用語

- **署名**：「このアプリは、この Apple ID の持ち主が作った」という印をアプリに付けること。iPhone は、署名の無いアプリを動かさない
- **Team ID**：Apple ID ごとに決まる、英数字10桁の番号。署名に使う
- **Bundle ID**：アプリを見分ける名前（例：`com.example.taro.appname`）
- **xcconfig**：Xcode のビルド設定を書いておけるテキストファイル
- **MCP**：AI ツールに外部の道具（ここではビルド）を使わせるための仕組み

## 1. 必要なもの

- Apple silicon の Mac（M1 以降）。macOS は最新
- Xcode 27（App Store から入れる）。2人とも同じメジャーバージョンに揃える
- iPhone（iOS 26 以上）と、つなぐケーブル
- Apple ID（無料でよい）
- Node.js 18 以上（XcodeBuildMCP を使う場合。https://nodejs.org/ から入れるか、Homebrew なら `brew install node`）

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

## 3. 署名の設定（人ごとに1回）

無料の Apple ID では、2人が同じ Bundle ID を使うと署名が衝突する。
そのため、人ごとに違う値を、git に入れないファイル（`Config/Local.xcconfig`）に書く。

1. `Config/Local.xcconfig.example` をコピーして、`Config/Local.xcconfig` という名前にする
2. `BUNDLE_ID_PREFIX` を、自分だけの値にする（例：`com.example.taro`。英数字とドットだけ）
3. `DEVELOPMENT_TEAM` に、自分の Team ID を書く。調べ方は次のどちらか
   - 「キーチェーンアクセス」アプリを開き、「Apple Development: （自分のメールアドレス）」という証明書の詳細を見る。「部署」の欄の英数字10桁が Team ID（証明書は、一度 Xcode で実機向けにビルドしようとすると作られる）
   - Xcode でターゲットの Signing & Capabilities を開き、Team に自分を一度選ぶ → `git diff` で `project.pbxproj` に出てくる `DEVELOPMENT_TEAM = XXXXXXXXXX` の値を控える → **`git checkout -- '*.pbxproj'` で変更を捨てる**（Team ID をコミットしないため）

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
| Antigravity | `AGENTS.md` を自動で読む。`.agents/rules/project.md` が追加のルールを取り込む | `.agents/mcp_config.json` |

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
- 効果音が鳴らない：iPhone がマナーモードになっていないか確認する

## 付録：プロジェクトを作る人が、最初に1回だけやること

Xcode でプロジェクトを新規作成した直後は、Bundle ID と Team ID がプロジェクトファイル（`project.pbxproj`）のターゲット側に書かれている。ターゲット側の値は xcconfig より優先されるので、そのままでは `Config/Local.xcconfig` が効かない。

1. Xcode で新規プロジェクトを作る。Product Name は `kouiunodeiindayo`（`Config/Base.xcconfig` の Bundle ID と揃える）。保存先はこのリポジトリの直下
2. Xcode でプロジェクト（青いアイコン）を選び、Info → Configurations で、Debug と Release の両方に `Base` を割り当てる
3. ターゲットの Build Settings で、次の行を選んで Delete キーで消す（太字でなくなれば、xcconfig の値が使われている）
   - Product Bundle Identifier
   - Development Team
   - iOS Deployment Target、Targeted Device Families、Supported Interface Orientations（`Base.xcconfig` に書いてあるもの）
4. Signing & Capabilities で「Automatically manage signing」はオンのまま。Team のプルダウンは触らない（選ぶと、Team ID がプロジェクトファイルに書き戻される）
5. 自分の `Config/Local.xcconfig` を作り（上の 3）、実機でビルドできることを確かめてからコミットする。コミット前に `git diff` で、`DEVELOPMENT_TEAM` に自分の Team ID が入っていないことを確かめる
6. 終わったら、この付録は残しておく（テスト用のターゲットを足したときも、同じ作業が要る）
