# push 前の確認手順

機能の実装が終わったとき、push する前、大きめの書き換えの後に通す。
各段階が失敗したら**そこで止めて直し**、最初からやり直す。

MCP（XcodeBuildMCP、Xcode の MCP）を入れている場合は、同じことを MCP のツールで行ってよい。

## 1. ビルド

```bash
set -o pipefail
xcodebuild -scheme Kouiunodeiindayo -destination 'generic/platform=iOS Simulator' build 2>&1 \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"
```

- リポジトリ直下で実行する（`.xcodeproj` が直下に1つだけある前提）
- スキーム（何をどうビルドするかの設定に付いた名前。ふつうはアプリ名と同じ）は `xcodebuild -list` で確認する
- `set -o pipefail` は、ビルドが失敗したことを終了コードで分かるようにするため。`grep` は、長い出力からエラー・警告・成否の行だけを抜き出すため
- 警告が増えていたら、できる範囲で直す

## 2. テスト（テストがある場合）

```bash
set -o pipefail
xcodebuild test -scheme Kouiunodeiindayo -destination 'platform=iOS Simulator,name=<シミュレータ名>' 2>&1 \
  | grep -E "error:|failed|passed|TEST (SUCCEEDED|FAILED)"
```

- シミュレータ名は `xcrun simctl list devices available` で確認する

## 3. 表示の確認

- 変更した画面のプレビュー、またはシミュレータで、表示が崩れていないかを見る
- 文字サイズを大きくした状態でも崩れないかを見る
- 確認した画面のスクショを `.verification/<Issue番号>/` に残す（git には入れない）。PR を出す前に本人が見返し、PR の「表示の確認」に貼る
  - ファイル名は「連番-操作-結果」（例：`02-サンプル追加-1件.png`）。プレビューは `preview-<ビュー名>.png`
  - 同じフォルダの `notes.md` に、写真ごとの「操作」と「見るところ」を表で書く
  - 貼り付けは `gh pr create` / `gh pr edit` の `--attach` で行う（gh 2.99 以上。`brew upgrade gh`）。本文に `![説明](.verification/10/01-起動直後-0件.png)` のように書いておくと、その場所に差し替わる

    ```bash
    gh pr edit <PR番号> --body-file body.md --attach '.verification/10/01-起動直後-0件.png#起動直後 0件'
    ```

## 4. 実機での確認（人が行う）

次のどれかを触った変更は、実機で確認するまで完了にしない。AI だけで「確認済み」にしない。

- カメラ（シミュレータでは動かない）
- スワイプの手触り、アニメーション
- 効果音（マナーモードのオン・オフの両方）
- 写真の保存・削除（アプリを終了して開き直しても残っているか）

## 5. Worker の確認

`server/` を触った変更だけ。手順の詳細は `docs/setup.md` の「7. Worker（中継サーバー）」。

1. 型の確認：`cd server && npm run check`
2. `npm run dev` で手元で動かす。**起動するのは人**（Vercel AI Gateway の API キーを `npm run dev -- --var AI_GATEWAY_API_KEY:<キー>` で渡す。環境変数では届かない。やり方は `docs/setup.md`）。AI ツールは起動しない。AI ツールは、起動済みの `localhost:8787` に叩くだけで、キーを読まない・ファイルに書かない
3. `SUGGEST_URL=http://localhost:8787 SUGGEST_TOKEN=<.dev.vars の値> scripts/try-suggest.sh` で、200／400／401／404／405 と、提案の中身（`genre` と `tags`）を見る。Jev は本物を呼んでクレジットを使うので、何度も回さない
4. 提案が全部 502 で、ログに `AI_GATEWAY_API_KEY not set` が出るときは、キー無しで起動している。人が起動し直す（AI ツールは 1 行で報告して止まる）

## 報告の形

```markdown
## 検証結果
- ビルド: ✅ / ❌
- テスト: ✅ / ❌（n passed / n failed）／ なし
- 表示の確認: 何をどう見たか1行
- 実機での確認: 済（誰が・何を） ／ 未（理由） ／ 不要
- Worker: ✅ / ❌ ／ 触っていない
```

「ビルドが通った」は「動く」ではない。
