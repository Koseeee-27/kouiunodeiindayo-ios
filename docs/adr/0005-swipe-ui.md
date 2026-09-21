# 0005: 仕分けのスワイプはライブラリを使わず自作する

- 状態：採用
- 日付：2026-09-21

## 決めたこと

仕分け画面のカード（指についてきて傾き、離すとその方向へ飛んでいく4方向のスワイプ）は、SwiftUI 標準の `DragGesture` と `offset` / `rotationEffect` で自作する。

## 理由

- 仕分けはこのアプリで一番こだわる画面。傾き方、方向の判定、飛び方、ラベルの強調を細かく調整したい
- 基本形は少ないコードで書ける（ジェスチャーの処理が約20行）
- 「ラベルを押しても仕分けできる」は、スワイプと同じ関数を呼ぶだけで済む
- 4方向に対応した SwiftUI のライブラリは更新が 2025-02 で止まっていて、Xcode 27 で動くかが分からない

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| `dadalar/SwiftUI-CardStackView` | 4方向に対応しているが、更新が止まっている。内部で並び順を持つので、仕分け待ちの並びを変えるときに扱いにくい |
| UIKit 製のライブラリ（Shuffle、Koloda） | 更新が止まり気味。SwiftUI に包む手間がかかる |

## 影響・注意

- 手触りはシミュレータと AI では確認できない。実機で人が触って調整する
- 回転は `offset` より先に書く（順序を逆にすると、回転した座標系で動いてしまう）
- スワイプの向きとジャンルの対応、操作と起きることは `docs/screen-design.md` の仕分けの項が正

## 出典

- https://www.hackingwithswift.com/books/ios-swiftui/moving-views-with-draggesture-and-offset
- https://github.com/dadalar/SwiftUI-CardStackView
