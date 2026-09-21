# こういうのでいいんだよ — Claude Code ガイド

ルールの正本は `AGENTS.md`（どの AI ツールでも共通）。このファイルには Claude Code だけに関係することを書く。

@AGENTS.md

コードを書く前に読むルール：

@docs/rules/swift.md
@docs/architecture.md

## Claude Code だけの設定

| 知りたいこと | 場所 |
|---|---|
| エージェント（planner / code-reviewer）の使い方 | `.claude/rules/common/agents.md` |
| push 前の確認を回すスキル | `.claude/skills/verification-loop/`（手順の正本は `docs/rules/verification.md`） |
| MCP（ビルド結果を AI に返す道具）の設定 | `.mcp.json`。入れ方は `docs/setup.md` |

- `.claude/settings.json` で、Claude のファイル編集ツールによる `project.pbxproj` の編集を禁止している。外さないこと（MCP のツール経由の変更までは止められないので、AGENTS.md の禁止事項も守る）
- 自分だけの設定を試したいときは `.claude/settings.local.json` に書く（git には入らない）
