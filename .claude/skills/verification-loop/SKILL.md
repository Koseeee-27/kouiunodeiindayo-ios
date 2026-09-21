---
name: verification-loop
description: コミット・push 前の品質ゲート。ビルド→テスト→表示の確認を順に通し、実機確認が要るかを判定して、壊れた状態での push を防ぐ。機能実装の完了時・push 前に使用する。
---

# verification-loop — push 前の品質ゲート

手順の正本は `docs/rules/verification.md`（どの AI ツールでも共通）。このスキルは、それを Claude Code で回すための入口。

1. `docs/rules/verification.md` を読む
2. 1〜3（ビルド、テスト、表示の確認）を順に実行する。失敗したらそこで止めて直し、最初からやり直す。MCP（XcodeBuildMCP、Xcode の MCP）が使えるなら、そのツールで行ってよい
3. 変更が 4（実機での確認）の対象かどうかを判定する。対象なら、何を実機で確認してほしいかを具体的に書いて人に頼む。自分で「確認済み」にしない
4. `docs/rules/verification.md` の「報告の形」で報告する
