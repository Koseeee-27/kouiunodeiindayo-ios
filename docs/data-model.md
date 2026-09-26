# データ設計

端末内に保存するデータの形。保存の仕組みを選んだ理由は `docs/adr/0002-local-storage.md`。
項目を足す・変えるときは、コードより先にこのファイルを直す。

## 記録（`Record`）

撮った写真1枚が、`Record` 1件。SwiftData のモデル。

仕様（要件定義・画面設計）でいう「記録」は、仕分けた写真だけを指す。仕分け待ちの写真は、まだ記録に入っていない扱いで、一覧にもホームにも出さない。データの上では、仕分け待ちの写真も同じ `Record` として持ち、`genre` が `unsorted` かどうかで見分ける。

| 項目 | 型 | 内容 |
|---|---|---|
| `id` | `UUID` | 記録の ID。写真のファイル名もこれから作る |
| `takenAt` | `Date` | 撮影日時。撮ったときに自動で付く（機能2）。あとから直せる（機能13）。カメラロールから取り込んだ写真（機能18）も、写真の撮影日時ではなく取り込んだ時刻にする |
| `createdAt` | `Date` | アプリに登録した日時。直せない |
| `photoFileName` | `String` | 写真のファイル名（例：`<id>.jpg`）。フォルダを含むフルの場所は保存しない（アプリの置き場所は変わることがある） |
| `genre` | `String` | ジャンル。下の表の値のどれか |
| `isFavorite` | `Bool` | お気に入り（うまい）が付いているか。既定は `false` |
| `tags` | `[String]` | 付いているタグのキー（下の「タグの値」）。既定は空 |
| `suggestedGenre` | `String?` | 提案したジャンル（`food`／`drink`／`dessert`）。問い合わせたが提案が無かったとき（自信が低い）と、まだ問い合わせていないときは `nil`（機能26） |
| `suggestedTags` | `[String]` | 提案したタグのキー。既定は空（機能26） |
| `suggestedAt` | `Date?` | 提案を問い合わせ終えた日時。提案が無かったときも書く。`nil` はまだ問い合わせていない（通信できなかった・時間切れのときも `nil` のまま） |

### ジャンルの値

| 値 | 意味 |
|---|---|
| `unsorted` | まだ仕分けていない（仕分け待ち）。撮った直後はこれ |
| `food` | 食べ物 |
| `drink` | 飲み物 |
| `dessert` | デザート |
| `none` | 「なし」で仕分けた。仕分け待ちには残らない |

- 文字列で保存する。コードでは `Genre` という enum（決まった選択肢を表す型）を用意し、`Record` には `genre`（文字列）と、enum に変換して返す計算プロパティ（保存せず、その場で計算して返す値）を持たせる
- enum の case 名に `none` を使わない。`Genre?` に対する `.none` は Swift では「値が無い」の意味に解釈され、比較が黙って外れる。保存する文字列は `"none"` のまま、case 名は `noGenre` にする（`case noGenre = "none"`）
- enum に変換する計算プロパティは optional にしない。知らない文字列が入っていたら `unsorted` として扱う
- 「まだ仕分けていない」を空（nil）にしない。`unsorted` という値で持つ
- 記録の詳細で、選択中のジャンルをもう一度押して外したときは `none` にする（仕分け待ちには戻さない）

### タグの値

タグの一覧（名前と3つの種類）は `docs/requirements.md` の「タグの一覧」が正。ここには保存するキーと、提案に使う対応を書く。

- 文字列のキーで保存する。コードでは `Tag` という enum に、日本語名・種類・下の対応を持たせる
- 知らないキーが入っていたら、表示しない（落とさない）
- 料理のタグは、Vision のラベル（右の列）のどれかが出たときだけ提案する。大分類と系統は、料理のタグから決まるものに加えて、Jev の判断でも提案する
- 記録の詳細で料理のタグを手で付けたときは、大分類・系統を自動では足さない

**料理**

| キー | 名前 | Vision のラベル | 大分類 | 系統 |
|---|---|---|---|---|
| `ramen` | ラーメン | `ramen` | `noodles` | `chinese` |
| `pasta` | パスタ | `pasta` `spaghetti` | `noodles` | `western` |
| `sushi` | 寿司 | `sushi` | `rice_dish` | `japanese` |
| `curry` | カレー | `curry` | `rice_dish` | — |
| `gyoza` | 餃子 | `gyoza` `dumpling` | — | `chinese` |
| `tempura` | 天ぷら | `tempura` | `fried` | `japanese` |
| `karaage` | 唐揚げ | `fried_chicken` | `fried` | — |
| `pizza` | ピザ | `pizza` | — | `western` |
| `hamburger` | ハンバーガー | `hamburger` | `bread` | `western` |
| `steak` | ステーキ | `steak` | `meat` | `western` |
| `sandwich` | サンドイッチ | `sandwich` | `bread` | `western` |
| `coffee` | コーヒー | `coffee` | — | — |
| `tea` | お茶 | `tea_drink` | — | — |
| `alcohol` | お酒 | `beer` `wine` `red_wine` `white_wine` `sparkling_wine` `cocktail` `liquor` | — | — |
| `juice` | ジュース | `juice` `smoothie` | — | — |
| `bubble_tea` | タピオカ | `bubble_tea` | — | — |
| `cake` | ケーキ | `cake` `cake_regular` `birthday_cake` `cheesecake` `cupcake` | — | — |
| `ice_cream` | アイス | `ice_cream` | — | — |
| `donut` | ドーナツ | `donut` | — | — |
| `baked_sweets` | 焼き菓子 | `cookie` `muffin` `pie` | — | — |

**大分類**：`noodles`（麺類）、`rice_dish`（ご飯もの）、`bread`（パン）、`meat`（肉料理）、`seafood`（魚介）、`fried`（揚げ物）、`egg`（卵料理）、`vegetables`（野菜・サラダ）、`soup`（汁物）

**系統**：`japanese`（和食）、`western`（洋食）、`chinese`（中華）、`korean`（韓国）、`ethnic`（エスニック）

## よく使う取り出し方

| 使う場面 | 条件 | 並び |
|---|---|---|
| 仕分け待ち（機能3・14。ホーム・一覧の入口から仕分けるとき） | `genre` が `unsorted` | `takenAt` の新しい順か古い順（設定値 `sortOrder`） |
| 仕分け待ちの枚数 | 上と同じ条件の件数 | — |
| カメラで撮った直後の仕分け | 今撮った1件（`id` で指定） | — |
| 一覧（機能6） | `genre` が `unsorted` 以外（仕分け待ちの写真は一覧に出さない。「なし」は出す） | `takenAt` の新しい順 |
| ホームの今日の一枚（機能23） | `genre` が `unsorted` 以外で、`takenAt` が今日。複数あるときは `takenAt` が一番新しい1枚 | — |
| 言葉で探す（機能28） | `genre` が `unsorted` 以外を `@Query` で取り、タグ・うまい・時期での絞り込みは取ったあとに Swift 側で行う（`tags` のような配列は `#Predicate` の中で使うと実行時に失敗する報告があるため）。料理のタグは、対応表で大分類・系統にも当てはめて判定する（「ラーメン」だけの記録も「麺類」「中華」で当たる） | `takenAt` の新しい順 |
| 提案を問い合わせる写真（機能26） | `genre` が `unsorted` で、`suggestedAt` が `nil` | `takenAt` の新しい順 |
| ホームの最近の写真（機能23） | `genre` が `unsorted` 以外で、今日の一枚を除く。4件 | `takenAt` の新しい順 |

## 写真ファイル

| 種類 | 置き場所 | ファイル名 | 目安 |
|---|---|---|---|
| 写真 | `Application Support/Photos/` | `<id>.jpg` | 長辺 2000px 前後、JPEG 品質 0.8 |
| サムネイル（一覧用） | `Application Support/Photos/` | `<id>_thumb.jpg` | 長辺 400px 前後 |

- 写真とサムネイルは、記録を追加するときに1回だけ作る
- サムネイルのファイル名は `id` から決まるので、データベースには保存しない
- 記録を消すときは、写真とサムネイルのファイルも一緒に消す
- 大きさと品質は目安。実機で見て調整してよい

## 設定値

データベースではなく `@AppStorage`（端末内の小さな設定の保存場所）に持つ。

| キー | 型 | 内容 |
|---|---|---|
| `launchScreen` | `String` | 開いたときの画面（機能25）。`camera`（初期設定）か `home` |
| `sortOrder` | `String` | 仕分け待ちを仕分ける順番（機能14）。`newest`（新しい順。初期設定）か `oldest`（古い順）。切り替えたら、次に開いたときもその順番のまま |

初回だけの説明（機能16）や、写真フォルダにも保存する設定（機能19）など、設定値が要る機能に着手するときは、キーをこの表に足してから実装する。

## 項目を足すときの決まり

- 足す項目は、既定値つきか optional（値が無くてもよい）にする。そうすれば、保存済みのデータはそのまま使える
- 項目の名前や型を変えない。変えたいときは、新しい項目を足して移す
- 開発中に起動時に落ちるようになったら、アプリを削除して入れ直す
