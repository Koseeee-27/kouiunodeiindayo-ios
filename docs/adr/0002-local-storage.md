# 0002: データは端末内に保存する（SwiftData + 写真ファイル）。サーバー無し

- 状態：採用
- 日付：2026-09-21

## 決めたこと

- サーバー・ログインは作らない。データはすべて端末内に置く
- 記録の情報（撮影日時、ジャンル、お気に入り）は SwiftData（Apple 純正の端末内データベース）に保存する
- 写真はデータベースに入れず、ファイルとして Application Support（アプリ専用の、利用者に見せないフォルダ）に保存する。データベースにはファイル名だけを持つ
- 一覧用の小さい画像（サムネイル）を、保存時に別ファイルで作る

データの形は `docs/data-model.md`。

## 理由

- ログインも共有機能も無いので、サーバーに置く理由が無い
- SwiftData は SwiftUI の `@Query` と組み合わせると、一覧・今日の一枚・仕分け待ちの取り出しが数行で書ける。学ぶ量が一番少ない
- 規模は数百〜数千件で、SwiftData の性能が問題になる範囲（数十万件）に入らない
- 写真をファイルで持つと、サムネイル・共有・デバッグが扱いやすく、あとで保存の仕組みを変えるときも写真はそのまま使える
- 一覧にフルサイズの写真を並べると、メモリ不足で落ちる。メモリの消費はファイルの大きさではなく画素数で決まる

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| Core Data | 実績は一番あるが、書く量と覚えることが多い |
| SQLite（GRDB） | 外部ライブラリが要る。SQL と SwiftUI との連携を自分で書く。SwiftData で行き詰まったときの退避先 |
| JSON ファイル | 絞り込みと画面の自動更新を自分で書くことになる |
| 写真をデータベースに入れる（`.externalStorage`） | 手軽だが、サムネイルやデバッグが扱いにくい |
| サーバーに保存する | 理由が無い。ネットワークが不安定な会場でデモが止まる |

## 影響・注意

- SwiftData には、メインスレッド以外で使うと画面が更新されないなどの不具合報告が残っている。メインスレッドの `modelContext` だけを使う
- enum をそのまま保存して絞り込みに使うと落ちる報告がある（iOS 27 で改善）。ジャンルは文字列で保存する
- 開発中にモデルを変えて起動時に落ちたら、アプリを削除して入れ直す。デモ機のデータは本番前に作り直す前提にする
- 「写真に AI で一言を付ける」をあとから足す場合は、空でもよい項目を足すだけで済む。端末上の AI（Vision、Foundation Models）か、クラウドの AI（API キーを隠すための中継サーバーが要る）かは、そのときに別の ADR で決める

## 出典

- https://developer.apple.com/documentation/updates/swiftdata
- https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/
- https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/
- https://azamsharp.com/2026/06/12/whats-new-in-swiftdata.html
- https://hackernoon.com/swiftdata-core-data-or-grdb-choose-by-the-queries-you-actually-run
- https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html
- https://nshipster.com/image-resizing/
- https://developer.apple.com/forums/thread/92693
