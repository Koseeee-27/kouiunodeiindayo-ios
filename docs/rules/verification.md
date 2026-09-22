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

## 4. 実機での確認（人が行う）

次のどれかを触った変更は、実機で確認するまで完了にしない。AI だけで「確認済み」にしない。

- カメラ（シミュレータでは動かない）
- スワイプの手触り、アニメーション
- 効果音（マナーモードのオン・オフの両方）
- 写真の保存・削除（アプリを終了して開き直しても残っているか）

## 報告の形

```markdown
## 検証結果
- ビルド: ✅ / ❌
- テスト: ✅ / ❌（n passed / n failed）／ なし
- 表示の確認: 何をどう見たか1行
- 実機での確認: 済（誰が・何を） ／ 未（理由） ／ 不要
```

「ビルドが通った」は「動く」ではない。
