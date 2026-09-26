# こういうのでいいんだよ — AI エージェント向けガイド

「こういうのでいいんだよ」— わざわざ撮らないような、いつものご飯を、つい撮って残したくなる iPhone の飯記録アプリ。
58ハッカソン2026 in 関西大学（2026-09-26〜27）の提出作品。

このファイルは**情報のハブ**で、どの AI ツール（Claude Code、Codex、Antigravity など）でも共通の正本。
詳細はここに書かず、各ドキュメントに置く。新しい情報も適切なドキュメントに追記し、必要ならこの表にリンクを足す。
`CLAUDE.md` と `.agents/rules/project.md` は、このファイルを読ませるための入口。内容を書き足さない。

## 前提（必ず守る）

| 項目 | 値 |
|---|---|
| 言語・UI | Swift + SwiftUI（UIKit はカメラを包む部分だけ） |
| 開発環境 | Xcode 27（Swift 6.4）。Apple silicon の Mac |
| 対応 OS | iOS 26 以上。iPhone のみ・縦画面のみ |
| データ | 端末内に保存（SwiftData + 写真ファイル）。ログイン無し |
| 通信 | ジャンルとタグの提案・言葉で探すのためだけに、中継サーバー（Cloudflare Worker。コードは `server/`）経由で AI（Jev）を呼ぶ。送るのは写っているものの名前と検索の言葉だけ |
| 外部ライブラリ | 使わない。足したいときは先に ADR（技術的な決定の記録。`docs/adr/`）を書いて相談する |

根拠は `docs/adr/`。ADR の決定が変わったら、この表も直す。

## ドキュメントの引き方

| 知りたいこと | 場所 |
|---|---|
| 何ができるアプリか（機能と優先度） | `docs/requirements.md` |
| どの画面に何を置くか・どう操作するか | `docs/screen-design.md` |
| 「記録」のデータの形、写真ファイルの置き場所 | `docs/data-model.md` |
| フォルダ構成、画面からデータを読み書きするときの決まり | `docs/architecture.md` |
| 技術的な決定と、その理由 | `docs/adr/` |
| 環境構築、実機に入れる手順、AI ツールの設定 | `docs/setup.md` |
| Swift / SwiftUI / SwiftData の書き方の決まり | `docs/rules/swift.md` |
| 言語を問わないコーディング原則 | `docs/rules/coding-style.md` |
| ブランチ・PR・コミットの決まり | `docs/rules/git-workflow.md` |
| push 前の確認手順（ビルド・テスト・実機） | `docs/rules/verification.md` |
| PR を出す前のセルフレビューの手順と、レビューの観点 | `docs/rules/self-review.md` |
| 開発タスク（何を・誰が・どこまで進んだか） | GitHub の Issues（ここが正。Notion のタスク管理には Issue の URL を貼るだけ） |
| 実装計画（Issue を、どのファイルをどんな手順で作るかに落としたもの） | `docs/plans/` |
| なぜ作るか（企画書）、見た目（デザイン要件書） | チームの Notion ポータル（このリポジトリには置かない） |

**コードを書く前に `docs/rules/swift.md` と `docs/architecture.md` を読むこと。**

## ドキュメントの決まり

- 同じ内容を2か所に書かない。必要ならリンクにする
- `docs/requirements.md` と `docs/screen-design.md` は Notion の下書き。決まったことだけを書く。案や未決事項は書かない。編集するのはこうせい（ほかの人と AI は、直したい点を見つけたら提案に留める）
- 仕様と実装が食い違ったら、どちらが正しいかを人に確認し、同じ PR で両方を揃える。黙って片方に合わせない
- 技術的な決定を変えるときは、古い ADR を書き換えず、新しい ADR を足して古いほうを「置き換え済み」にする

## 禁止事項

- `*.xcodeproj/project.pbxproj` を直接編集しない。ファイルの追加は、同期フォルダ（Xcode が中身を自動で認識するフォルダ）の中に置くだけでよい。ビルド設定の変更が必要なときは、人が Xcode で行う
- 外部ライブラリ（Swift Package）を勝手に足さない
- SwiftData をメインスレッド以外で使わない（詳細は `docs/rules/swift.md`）
- iOS 26 より新しい API を、OS のバージョンを確かめる `if #available` 無しで使わない。存在が不確かな API は、Apple の公式ドキュメントで確認してから使う
- 署名の設定（`DEVELOPMENT_TEAM`、Bundle ID）をコミットしない。個人ごとの値は `Config/Local.xcconfig`（git に入れない）に書く
- API キーなどのシークレットをコードやリポジトリに入れない

## 開発フロー

会話ではなくファイルで工程をつなぐ。成果物は git にコミットして共有する。

```
タスク    → GitHub の Issue（何を作るか・完成の条件・担当）
実装計画  → docs/plans/<機能名>.plan.md （どのファイルを・どんな手順で・確認方法）
実装      → Issue ごとにブランチを切って、コード（計画に従う）
検証      → docs/rules/verification.md の手順（ビルド → テスト → 実機確認）
レビュー  → docs/rules/self-review.md の手順（別の会話の AI に差分を見せて、直す。最大3周）
PR        → 説明に「Closes #Issue番号」を書く。要所の PR だけ、Copilot か相方にレビューを頼む
マージ    → squash merge（PR のコミットを1つにまとめて main に入れる）。Issue は自動で閉じる
```

- 小さな修正は計画を飛ばして直接実装してよい。Issue も、数分で終わる修正なら無くてよい
- タスクを Issue 以外の場所（ドキュメント、コードのコメント、会話）に溜めない。見つけたやることは Issue にする
- plan ファイルは、Issue を実装の手順に落としたもの。書いた人と実装する人が別でもよい
- カメラ・スワイプの手触り・効果音は、シミュレータと AI では確認できない。必ず人が実機で確認する

## Git の要点

詳細は `docs/rules/git-workflow.md`。

- main に直接 push できない（GitHub 側で禁止している）。ブランチを切って PR でマージする（`feat/12-〜`、`fix/34-〜` など、Issue 番号を入れる）
- コミットメッセージと PR の題名は `feat: 〜` のように種類を先頭に付け、日本語で簡潔に書く。AI の署名（Co-Authored-By など）は付けない
- 壊れた状態で push しない
- こまめに pull する
