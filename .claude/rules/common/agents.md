# エージェント運用ルール（Claude Code 用）

Claude Code で使えるエージェントと、いつ・どう使うかのルール。どの AI ツールにも共通のルールは `AGENTS.md`。
（参考: [ECC](https://github.com/affaan-m/ECC) の rules/common/agents.md の型を採用）

## エージェント一覧

`.claude/agents/` に定義。

| エージェント | 役割 | 使うとき |
|---|---|---|
| planner | 実装計画の作成 | 新機能・大きめの変更の前 |
| code-reviewer | コードレビュー | PR を出す前のセルフレビュー（self-review スキルから呼ぶ） |

## 自動起動の条件

ユーザーが指示しなくても、以下の場面では該当エージェントを使う：

1. 複数ファイルにまたがる機能の実装依頼 → **planner** で計画を作り `docs/plans/` に保存してから実装する
2. コミット・push の前 → **verification-loop** スキル（手順の正本は `docs/rules/verification.md`）を通す
3. PR を作る前 → **self-review** スキル（手順の正本は `docs/rules/self-review.md`）を回す。レビューは **code-reviewer** エージェントに任せ、実装した会話の中で自分ではレビューしない

## サブエージェントへの依頼のしかた

- **目的を必ず渡す**。「何を調べるか」だけでなく「何のために必要か」を含める（目的を知らないエージェントは的外れな要約を返す）
- 独立した作業は**並列**でエージェントを起動する（順番に待たない）
- 成果物は会話の中に留めず、**ファイルに保存**する（`docs/plans/` 等）。次の工程はそのファイルパスを入力にする

## 計画→実装の受け渡し

plan ファイルの役割とフォーマットは `docs/plans/README.md` が正。
