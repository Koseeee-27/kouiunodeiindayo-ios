# 実装計画: アルバムから 1 枚だけ選んだときは、食事の判定で除かない

## 概要

ホームの「アルバムから取り込む」（#102）で 1 枚だけ選んだときは、Vision の食事の判定で除かずに取り込む。対応する Issue：#110（親 #86）。対応する機能：機能18。取り込みの全体は `docs/plans/photo-import.plan.md`（マージ済み。書き換えない）。

main から `feat/110-single-photo` を切って作る。**目安：30 分**。

## 決めたこと（2026-09-27、こうせいと確認）

- 1 枚だけのときは除かない。2 枚以上は今どおり除く。件数の 1 行・読めなかったときの扱いは今のまま

## ステップ

1. `Kouiunodeiindayo/Features/Import/PhotoImporter.swift` の `PhotoImportRunner.run` — `items.count == 1` のときは `labels` を呼ばず（Vision を動かさず）、そのまま保存する。今の `if !FoodPhotoFilter.isFood(try await labels(prepared.image))` の前に条件を 1 つ足す。コメントに「本人が選んだ 1 枚は除かない（#110）」
2. `KouiunodeiindayoTests/PhotoImporterTests.swift` — 1 枚・食事らしくない（差し替えた `labels` が `desk` だけを返す）→ 取り込み 1・除外 0、`labels` は呼ばれない／2 枚・1 枚が食事らしくない → 取り込み 1・除外 1（今のテストにあれば、それで足りる）
3. 確認：`docs/rules/verification.md` の 1・2。シミュレータでは Vision が動かないので、画面での確認は要らない
4. `docs/requirements.md` の機能18 に「1 枚だけ選んだときは除かない」を足す（PR #115 のあと。こうせいの OK 済みなので直してよい）。`docs/screen-design.md` は変えない
5. コミット `feat: アルバムから 1 枚だけ選んだときは食事の判定で除かない (#110)`

## リスク

- 無し（分かれ道が 1 つ増えるだけ）。1 枚だけ選んだ料理でない写真は、仕分けで「なし」にする
