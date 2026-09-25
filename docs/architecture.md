# アプリの構成

フォルダの分け方と、画面からデータを読み書きするときの決まり。
2人が別々の画面を作っても噛み合うように、先に「境界」を決めておくための文書。

## フォルダ構成

```
Kouiunodeiindayo/
├── App/
│   ├── KouiunodeiindayoApp.swift    ← 起動の入口。SwiftData の準備（ModelContainer）もここ
│   ├── RootView.swift         ← 開いたときの画面の切り替え（カメラ／ホーム）と、画面の行き来
│   ├── RootTab.swift          ← 下タブの行き先の enum（並び順・文言・アイコン）
│   ├── RootTabBar.swift       ← 自作の下タブのバー（見た目と押したときの通知）
│   └── StartTab.swift         ← 開いたときにどのタブから始めるかの設定値（機能25）の enum とキー
├── Features/                  ← 画面ごとに1フォルダ
│   ├── Home/
│   │   ├── HomeView.swift         ← 今日の一枚・最近の写真・仕分け待ちの入口・撮るボタン
│   │   ├── RecordPhotoView.swift  ← 記録1件の写真かサムネイルを PhotoStorage から読むビュー。一覧のグリッドでも使える
│   │   └── HomePreviewData.swift  ← ホームのプレビュー用のサンプルデータ
│   ├── List/
│   ├── Camera/
│   │   ├── CameraView.swift       ← 標準カメラの包み。口は onPick / onCancel
│   │   └── CameraFlowView.swift   ← 撮る → 保存 → 仕分けの切り替え。カメラのカバーの中身。許可の状態で、カメラか案内かを振り分ける
│   ├── Sort/                  ← 仕分け
│   │   ├── SortView.swift         ← 仕分けの画面。上の行・残り枚数・抜ける手段
│   │   ├── SortCardStackView.swift ← カードの重なり・縁のラベル・ドラッグと飛ばす処理
│   │   ├── SortCardView.swift     ← 写真1枚のカードと「う、うまい」
│   │   ├── SortGenreLabelView.swift ← 縁に重ねるチップ。押すと仕分け・ドラッグ中の強調
│   │   ├── SortStampView.swift    ← ドラッグ中のスタンプ（見た目は仮）
│   │   ├── SortPreviewData.swift  ← 仕分けのプレビュー用のサンプルデータ
│   │   └── SwipeDirection.swift   ← 向き → ジャンル、しきい値・傾き・飛び方の定数
│   ├── Detail/
│   │   └── RecordDetailView.swift ← 記録の詳細
│   ├── Onboarding/            ← 初めて開いたときの説明、カメラの許可を断られたときの案内
│   │   └── CameraAccessGuideView.swift ← カメラの許可を断られた・制限されているときの案内。設定を開く・アルバムから選ぶ・ホームへ
│   └── Settings/
├── Data/
│   ├── Record.swift           ← SwiftData のモデル（docs/data-model.md のとおり）
│   ├── Genre.swift            ← ジャンルの enum
│   ├── RecordStore.swift      ← 書き込みの入口（下の「書くとき」）
│   ├── PhotoStorage.swift     ← 写真ファイルの保存・読み込み・サムネイル作成・削除
│   ├── SampleData.swift       ← プレビュー用のサンプルデータ
│   └── Logging.swift          ← ログ（os.Logger）の共通設定
├── Design/
│   ├── Theme.swift            ← 色・フォント・余白の定義
│   ├── TitleLogoView.swift    ← 左上の見出しのタイトルロゴ（ホームと一覧で共通。素材は Assets の TitleLogo）
│   └── SoundPlayer.swift      ← 効果音の再生
└── Resources/                 ← フォント、効果音、画像（Assets）
Config/
├── Base.xcconfig              ← 全員共通のビルド設定（対応 OS、縦画面のみ、カメラの文言など）
└── Local.xcconfig.example     ← 個人ごとの署名設定の見本（docs/setup.md）
```

- どの画面があるか、何を置くかは `docs/screen-design.md` が正。ここには書かない
- ホーム・一覧・カメラの行き来は下タブ（左からカメラ／ホーム／一覧。`docs/screen-design.md` の「ナビゲーション」）。下タブは `RootView` が持つ。バーは自作（`RootTabBar`）。ホーム⇄一覧は `TabView` の `.page` で横にめくる。カメラは `RootView` が `fullScreenCover` で出す。撮ったあとの仕分けも同じカバーの中で `CameraFlowView` が切り替える。仕分けは `dismiss()` で閉じ、閉じるとホームに戻る。設定はホーム右上のアイコンから、ホームが `sheet` で `SettingsView` を出す
- ホーム・一覧の仕分け待ちの入口は、それぞれの画面が `fullScreenCover` で `SortView` を出す。記録の詳細は、ホーム・一覧のそれぞれが `sheet` で開く（閉じても、元の画面のスクロール位置が残る）
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
| 撮影日時を変える（記録、日時） | `takenAt` を書き換える（機能13） |
| 消す（記録） | 記録と、写真・サムネイルのファイルを消す（機能11） |
| すべて消す | すべての記録と、写真・サムネイルのファイルを消す（機能20） |

書き込みの入口を1か所にまとめる理由：保存の仕方（ファイル名の付け方、サムネイルの作り忘れ、消し忘れ）が、画面ごとにずれないようにするため。

### 写真を表示するとき

- 一覧など小さく並べる場所は、サムネイルを使う
- ホームの今日の一枚、仕分けのカード、記録の詳細は、写真本体を使う
- どちらも `PhotoStorage` から読む。画面でファイルの場所を組み立てない

## 並行して作るための約束

- 最初に `Data/` の4ファイル（`Record`、`Genre`、`RecordStore`、`PhotoStorage`）と `SampleData` を作ってから、画面に分かれる
- 画面は、サンプルデータを入れたプレビューで見た目を作れるようにする。カメラやほかの画面の完成を待たない
- 効果音と色・フォントは、`SoundPlayer` と `Theme` の呼び方だけ先に決め、中身（音源・配色）はあとから差し替える
- 見た目は、まず標準の部品のままシンプルに作る。デザインが決まった部分から、`Theme` と各画面に順に反映していく。最初から作り込まない
