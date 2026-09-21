# こういうのでいいんだよ

「こういうのでいいんだよ」— わざわざ撮らないような、いつものご飯を、つい撮って残したくなる iPhone の飯記録アプリ。

58ハッカソン2026 in 関西大学 提出作品。

## はじめに

```bash
git clone <このリポジトリのURL>
```

環境構築と、自分の iPhone で動かすまでの手順は [`docs/setup.md`](docs/setup.md)。

## ドキュメント

| 知りたいこと | 場所 |
|---|---|
| 何ができるアプリか | [`docs/requirements.md`](docs/requirements.md) |
| 画面と操作 | [`docs/screen-design.md`](docs/screen-design.md) |
| データの形 | [`docs/data-model.md`](docs/data-model.md) |
| フォルダ構成とコードの境界 | [`docs/architecture.md`](docs/architecture.md) |
| 技術的な決定と理由 | [`docs/adr/`](docs/adr/) |

## AI と一緒に開発する

AI 向けのルールの正本は [`AGENTS.md`](AGENTS.md)。Claude Code、Codex、Antigravity のどれでも、リポジトリを開くだけで同じルールが読み込まれる。
ツールごとの設定の入れ方は [`docs/setup.md`](docs/setup.md) の「AI ツールの設定」。

- ルールを変えたら、Discord で一言共有する（ほかの人は pull すると反映される）
- 自分だけの設定を試したいときは、git に入らない個人用の設定ファイルに書く（Claude Code なら `.claude/settings.local.json`）
