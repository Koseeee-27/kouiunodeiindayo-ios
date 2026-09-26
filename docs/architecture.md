# アプリの構成

フォルダの分け方と、画面からデータを読み書きするときの決まり。
2人が別々の画面を作っても噛み合うように、先に「境界」を決めておくための文書。

## フォルダ構成

```
Kouiunodeiindayo/
├── App/
│   ├── KouiunodeiindayoApp.swift    ← 起動の入口。SwiftData の準備（ModelContainer）もここ
│   ├── LaunchSplashView.swift ← 起動画面の絵を1秒見せてから、本物の画面（RootView）に切り替える
│   ├── RootView.swift         ← 開いたときの画面の切り替え（カメラ／ホーム）と、画面の行き来
│   ├── RootTab.swift          ← 下タブの行き先の enum（並び順・文言・アイコン）
│   ├── RootTabBar.swift       ← 自作の下タブのバー（見た目と押したときの通知）
│   └── StartTab.swift         ← 開いたときにどのタブから始めるかの設定値（機能25）の enum とキー
├── Features/                  ← 画面ごとに1フォルダ
│   ├── Home/
│   │   ├── HomeView.swift         ← 今日の一枚・最近の写真・仕分け待ちの入口・撮るボタン・アルバムからの取り込みの入口と取り込み中の幕
│   │   ├── RecordPhotoView.swift  ← 記録1件の写真かサムネイルを PhotoStorage から読むビュー。一覧のグリッドでも使う（一覧の「うまい」は枠からはみ出させるので、枠のあとに重ねる）
│   │   └── HomePreviewData.swift  ← ホームのプレビュー用のサンプルデータ
│   ├── Import/
│   │   ├── PhotoImporter.swift    ← アルバムからの取り込み（機能18）。受け取り・縮小・撮影日時・食事の判定・保存を 1 枚ずつ。画面は持たない
│   │   └── PhotoImportingOverlayView.swift ← 取り込み中の幕（`RootView` が重ねる）
│   ├── List/
│   │   └── RecordListView.swift   ← 一覧。言葉で探す欄と、読み取った条件での絞り込み（機能28）
│   ├── Camera/
│   │   ├── CameraView.swift       ← 標準カメラの包み。口は onPick / onCancel
│   │   └── CameraFlowView.swift   ← 撮る → 保存 → 仕分けの切り替え。カメラのカバーの中身。許可の状態で、カメラか案内かを振り分ける
│   ├── Sort/                  ← 仕分け
│   │   ├── SortView.swift         ← 仕分けの画面。上の行・残り枚数・抜ける手段。`recordID` を渡すと、撮った直後の1枚だけを出す。`importedIDs` を渡すと、アルバムから取り込んだ写真だけを出す。右上の「おまかせ」（任せられる写真を先頭に出して、`SortCardStackView` に 1 枚ずつ飛ばしてもらう）
│   │   ├── SortCardStackView.swift ← カードの重なり・縁のラベル・ドラッグと飛ばす処理。下のラベルの下に、提案されたタグの行を置く
│   │   ├── SortCardView.swift     ← 写真1枚のカードと「う、うまい」
│   │   ├── SortGenreLabelView.swift ← 縁に置く吹き出しのラベル（上下はカードの外）。押すと仕分け・ドラッグ中の強調・提案されたジャンルの点線
│   │   ├── SortSuggestedTagsView.swift ← 提案されたタグの − つきのチップ（`TagChipView`）の行。押すと外す・付ける
│   │   ├── SortTagSelection.swift ← 付いているタグ（提案 − 外したもの）と、次に進むときの書き込み（タグ → ジャンル）
│   │   ├── SortStampView.swift    ← ドラッグ中のスタンプ（見た目は仮）
│   │   ├── AutoSortPolicy.swift   ← おまかせで任せる写真の決まりと、確率の境目（アプリの定数）
│   │   ├── SortPreviewData.swift  ← 仕分けのプレビュー用のサンプルデータ
│   │   └── SwipeDirection.swift   ← 向き → ジャンル、しきい値・傾き・飛び方の定数
│   ├── Detail/
│   │   ├── RecordDetailView.swift ← 記録の詳細。入り切らないとき（タグが多い・文字が大きい）だけ縦にスクロールする
│   │   ├── RecordDetailTagsView.swift ← 詳細の、付いているタグの行（− で外す・「＋ タグ」で一覧を開く。折り返す）
│   │   ├── TagPickerView.swift    ← タグの一覧のシート（種類ごとの見出し。押すと付け外し。押した時点で保存）
│   │   └── TagEditing.swift       ← タグの付け外しの計算（書き込みは `RecordStore` の「タグを変える」）
│   ├── Onboarding/            ← 初めて開いたときの説明、カメラの許可を断られたときの案内
│   │   └── CameraAccessGuideView.swift ← カメラの許可を断られた・制限されているときの案内。設定を開く・アルバムから選ぶ・ホームへ
│   └── Settings/
├── Data/
│   ├── Record.swift           ← SwiftData のモデル（docs/data-model.md のとおり）
│   ├── Genre.swift            ← ジャンルの enum
│   ├── Tag.swift              ← タグの enum（名前・種類・Vision のラベルとの対応。docs/data-model.md のとおり）
│   ├── RecordStore.swift      ← 書き込みの入口（下の「書くとき」）
│   ├── PhotoStorage.swift     ← 写真ファイルの保存・読み込み・サムネイル作成・削除
│   ├── SampleData.swift       ← プレビュー用のサンプルデータ
│   └── Logging.swift          ← ログ（os.Logger）の共通設定
├── Suggestion/                ← ジャンルとタグの提案（機能26）、言葉で探す（機能28）。理由は docs/adr/0006
│   ├── ImageLabeler.swift     ← Vision で写真からラベルを取り出す（端末の中だけ）
│   ├── FoodPhotoFilter.swift  ← Vision のラベルから、食事らしい写真かを決める（アルバムからの取り込みの除外）
│   ├── SuggestionClient.swift ← Worker への通信。URL と合言葉は Config/Local.xcconfig から読む
│   ├── SuggestionService.swift ← まとめ役。プロトコルにして、プレビュー用のモックも用意する
│   ├── SuggestionMock.swift   ← 通信せずに決まった提案を返すモック
│   ├── SearchCondition.swift  ← 言葉で探す（機能28）の条件（タグ・うまい・時期）
│   ├── LocalSearchParser.swift ← 言葉から条件を端末の中で読み取る（タグの名前・「うまい」・時期の言葉）
│   └── RecordSearchFilter.swift ← 条件で記録を絞り込む（料理のタグは大分類・系統にも当てはめる）
├── Design/
│   ├── Theme.swift            ← 色・フォント・余白の定義
│   ├── TitleLogoView.swift    ← 左上の見出しのタイトルロゴ（ホームと一覧で共通。素材は Assets の TitleLogo）
│   ├── SortEntryBubbleView.swift ← 仕分け待ちへの入口の吹き出し（ホームと一覧で共通）
│   ├── PhotoFrame.swift       ← 写真の墨のコマ枠（`.photoFrame(.main / .small)`）
│   ├── TagChipView.swift      ← タグのチップ（付いている：− ／ 外した：点線と ＋）と、タグを足す入口のチップ。仕分け・詳細・タグの一覧で共通
│   ├── FlowLayout.swift       ← 子を左から並べて、入らなければ次の行に送るレイアウト（タグのチップの折り返し）
│   └── SoundPlayer.swift      ← 効果音の再生
└── Resources/                 ← フォント、効果音、画像（Assets）、起動画面（LaunchTitleV2.storyboard。絵は Assets の LaunchTitleV2）
Config/
├── Base.xcconfig              ← 全員共通のビルド設定（対応 OS、縦画面のみ、カメラの文言など）
├── Info.plist                 ← 独自のキー（Worker の URL と合言葉）だけの Info.plist。値は Local.xcconfig から入る（docs/setup.md の 7）
└── Local.xcconfig.example     ← 個人ごとの署名設定・Worker の URL と合言葉の見本（docs/setup.md）
KouiunodeiindayoTests/         ← テスト（Swift Testing）。同期フォルダなので、ファイルを置くだけでよい
server/                        ← 中継サーバー（Cloudflare Worker）。Jev を呼んで、ジャンル・タグ・検索の条件を返す
```

- どの画面があるか、何を置くかは `docs/screen-design.md` が正。ここには書かない
- ホーム・一覧・カメラの行き来は下タブ（左からカメラ／ホーム／一覧。`docs/screen-design.md` の「ナビゲーション」）。下タブは `RootView` が持つ。バーは自作（`RootTabBar`）。ホーム⇄一覧は `TabView` の `.page` で横にめくる。カメラは `RootView` が `fullScreenCover` で出す。撮ったあとの仕分けも同じカバーの中で `CameraFlowView` が切り替える。仕分けは `dismiss()` で閉じ、閉じるとホームに戻る。設定はホーム右上のアイコンから、ホームが `sheet` で `SettingsView` を出す
- ホーム・一覧の仕分け待ちの入口は、それぞれの画面が `fullScreenCover` で `SortView` を出す。アルバムからの取り込みは、ホーム右上の入口から `PhotosPicker` で選び、取り込み後にホームが `fullScreenCover` で `SortView(importedIDs:importSummary:)` を出す。取り込み中は、ホームが進み具合を `RootView` に知らせ、`RootView` がページャーと下タブの上に幕（`PhotoImportingOverlayView`）を重ねて、どちらも触れなくする（終わったときの仕分けのカバーが、カメラ・一覧の仕分けのカバーと重ならないように）。記録の詳細は、ホーム・一覧のそれぞれが `sheet` で開く（閉じても、元の画面のスクロール位置が残る）
- ビューの型名は `〜View` にする（`List/` フォルダのビューは `RecordListView` など。SwiftUI の `List` と同じ名前にしない）
- ファイルを足すときは、このフォルダの中に置くだけでよい（同期フォルダなので、Xcode が自動で認識する）

## 画面とデータの境界

### 読むとき

各画面が SwiftData の `@Query`（条件を書くと、結果が自動で更新される仕組み）を直接使う。
条件と並びは `docs/data-model.md` の「よく使う取り出し方」に合わせる。

### 書くとき

必ず `RecordStore` の関数を通す。画面から `modelContext.insert` / `delete` や、ファイルの書き込みを直接呼ばない。

| 関数 | すること |
|---|---|
| 追加（写真、撮影日時） | 写真とサムネイルをファイルに保存し、`genre = unsorted` の記録を作る |
| ジャンルを変える（記録、ジャンル） | `genre` を書き換える。仕分けのスワイプ、ラベルのタップ、詳細での付け直しが、どれもこれを呼ぶ |
| うまいを切り替える（記録） | `isFavorite` を反転する |
| タグを変える（記録、タグ） | `tags` を書き換える。仕分けでジャンルを付けて次に進むとき（そのとき付いているタグで書く）、詳細での付け直しが、どれもこれを呼ぶ。重複を除き、タグの一覧の順（`Tag.allCases`）に並べ直して書く。今の `tags` にある知らないキーは消さずにうしろに残す（画面は知らないキーを除いたタグで渡してくるため） |
| 提案を保存する（記録の `id`、ジャンル、タグ） | `id` で記録を取り直し、`suggestedGenre`・`suggestedGenreConfidence`（ジャンルがあるときだけ）・`suggestedTags`・`suggestedAt` を書く。`tags` には触らない（仕分けの画面が `suggestedTags` を最初の状態として持ち、次に進むときに「タグを変える」で書く）。記録が消えていた・もう仕分け済みなら、何も書かない。もう問い合わせ済み（`suggestedAt` が入っている）なら、何も書かない（先に届いたほうを使う。仕分けの画面で外したタグが、あとから届いた提案で戻らないように） |
| 撮影日時を変える（記録、日時） | `takenAt` を書き換える（機能13） |
| 消す（記録） | 記録と、写真・サムネイルのファイルを消す（機能11） |
| すべて消す | すべての記録と、写真・サムネイルのファイルを消す（機能20） |

書き込みの入口を1か所にまとめる理由：保存の仕方（ファイル名の付け方、サムネイルの作り忘れ、消し忘れ）が、画面ごとにずれないようにするため。

### 写真を表示するとき

- 一覧など小さく並べる場所は、サムネイルを使う
- ホームの今日の一枚、仕分けのカード、記録の詳細は、写真本体を使う
- どちらも `PhotoStorage` から読む。画面でファイルの場所を組み立てない

### 提案（機能26）の流れ

```
追加（写真を保存）→ 裏で SuggestionService：ImageLabeler（Vision）→ SuggestionClient（Worker → Jev）
                  → メインスレッドで RecordStore の「提案を保存する」→ 仕分け画面は @Query で自動で更新される
```

- 問い合わせを始めるのは2か所：撮った直後（`CameraFlowView` が `RecordStore` の「追加」のあとに呼ぶ）と、仕分けの画面を開いたとき（`SortView` が、仕分け待ちのうち `suggestedAt` が `nil` の写真を問い合わせる）
  - アルバムからの取り込みでは頼まない。取り込み後に開く仕分けの画面が、画面に出る順に頼む（取り込み側からも頼むと、選んだ順で待ち行列に入り、先頭の写真の提案が遅れる）
- Worker はジャンルの確率（`genreConfidence`）も返し、`suggestedGenreConfidence` に保存する。おまかせは、仕分けの画面に出ている写真のうち確率が境目（`AutoSortPolicy.threshold`）以上のものだけを、手で仕分けたときと同じ書き込み（タグ → ジャンル。`SortTagSelection.commit`）で確定する。おまかせ専用の書き込みの関数は作らない
- 裏の処理には、`Record` そのものではなく `id` と `photoFileName` だけを渡す（`@Model` はスレッドをまたいで渡せない）。結果を保存するときに、メインスレッドで `id` から記録を取り直す
- アプリと Worker の受け渡しの形（送る JSON・返る JSON・合言葉のヘッダー）は `docs/suggestion-api.md`
- 仕分けの画面は、提案を待たずに写真を出す。提案は `Record` に保存された時点で画面に出る
- 自信が低いとき（Worker が「提案なし」と返したとき）も問い合わせ済みにする：`suggestedAt` を書き、`suggestedGenre` は `nil`、`suggestedTags` は空
- 通信できない・時間切れ（目安 1.5 秒）・Worker が 200 以外を返したときは、その場で 2 秒・5 秒以上あけて（失敗が続いて問い合わせの間が広がっているときは、その間に合わせて）最大 2 回問い合わせ直す（Vision の失敗と、送れるラベルが無いときは問い合わせ直さない）。それでもだめなら何も保存しない（`suggestedAt` は `nil` のまま）。次に仕分けの画面を開いたときに、もう一度問い合わせる
- 同じ写真は重ねて問い合わせない（撮った直後は、カメラ側と仕分けの画面の両方から頼まれる）。問い合わせは受け付けた順に1件ずつ行う。問い合わせ直しを待っている写真は後回しにし、その間もほかの写真を問い合わせる
- ふだんは問い合わせの間を空けない。失敗したら問い合わせの間を広げ（1 秒から倍々、上限 8 秒）、成功が 3 回続くたびに半分にして、0.5 秒を切ったら空けないのに戻す。前の問い合わせから 30 秒以上あいたら、すぐ空けないのに戻す。端末が通信できない（機内モード・圏外など）ときの失敗では広げない（Worker の回数の制限に合わせるため。決まりは `LiveSuggestionService.RetryPolicy`）
- Worker の URL か合言葉が未設定（`Config/Local.xcconfig` に書いていない）なら、問い合わせない。撮る・仕分けるはそのまま
- 画面から `SuggestionClient` を直接呼ばない。`SuggestionService` を `@Environment` で受け取る。既定は何もしないモックで、本物はアプリの入口（`KouiunodeiindayoApp`）で渡す。プレビューで提案を見たいときはモック（`SuggestionMock`）を渡す

## 並行して作るための約束

- 最初に `Data/` の4ファイル（`Record`、`Genre`、`RecordStore`、`PhotoStorage`）と `SampleData` を作ってから、画面に分かれる
- 画面は、サンプルデータを入れたプレビューで見た目を作れるようにする。カメラやほかの画面の完成を待たない
- 効果音と色・フォントは、`SoundPlayer` と `Theme` の呼び方だけ先に決め、中身（音源・配色）はあとから差し替える
- 提案は `SuggestionService` のモックで画面を先に作れる。Worker の完成を待たない
- 見た目は、まず標準の部品のままシンプルに作る。デザインが決まった部分から、`Theme` と各画面に順に反映していく。最初から作り込まない
