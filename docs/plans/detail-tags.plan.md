# 実装計画: 記録の詳細で、タグを見て足す・外す

## 概要

記録の詳細（`RecordDetailPageView`）に、付いているタグを並べる。並んだタグの − で外し、「＋」からタグの一覧を開いて足す・外す。その場で変わり、保存ボタンは無い。書き込みは `RecordStore.setTags`（「タグを変える」）を通す。対応する Issue：#84（親 #86）。対応する機能：`docs/requirements.md` の機能27（タグを付ける）・機能12（仕分けのやり直し）の記録の詳細の部分。

要素と操作は `docs/screen-design.md`「記録の詳細」（「タグを付け直す（機能12・27）｜その場で変わる。保存ボタンは無い。タグの一覧から足す・外す」）、タグの一覧は `docs/requirements.md`「タグの一覧」、保存するキーは `docs/data-model.md`「タグの値」、書き込みの決まりは `docs/architecture.md`「書くとき」の「タグを変える」が正。見た目は仕分けのタグのチップ（ワイヤー集「タグの見せ方」の 2b。#83 で実装済み）に揃える。

**ブランチは `feat/84-detail-tags`（2026-09-27 に main から切った。#102・#103 はまだ未マージ）。** 記録の詳細は #102・#103 では触らないので、ぶつかるのは下の「チップを共通にする」で仕分けのファイルを 1 つ動かすところだけ。

## 決めたこと（全部推奨、2026-09-27 こうせい確認）

本文の「要判断 n」は、この番号を指す。

1. **タグの行を置く場所**：ジャンルのボタンの下（一番下）。記録の詳細の案 A〜F が決まったら、その案のタグの位置に移す
2. **足す・外すのやり方**：詳細には付いているタグを − つきのチップで並べ（押すと外れる）、最後に「＋ タグ」のチップ。＋ でタグの一覧をシート（半分の高さ・引き上げると全画面）で開き、押して付け外しする
3. **タグが多いとき**：折り返して複数行にする（横スクロールにすると、ページのめくりと取り合う）
4. **タグが 0 個のとき**：「＋ タグを足す」のチップだけを出す（付いているときは「＋ タグ」）。読み上げは「タグを足す」
5. **シートの中**：見出し「料理」「大分類」「系統」の下に `Tag.allCases` の順でチップを折り返して並べる。付いているチップは仕分けの「付いている」形、付いていないチップは「外した」形。右上に「完了」（閉じるだけ）
6. **料理のタグを足したとき**：大分類・系統は自動では付けない（`docs/data-model.md`「タグの値」のとおり）

## 実装で計画から変えたこと（2026-09-27）

- 詳細の「縦に収まらないとき」は、計画のとおり `ViewThatFits(in: .vertical) { 今の並び; ScrollView { 今の並び } }` にした。1 画面に収める版は写真の最小の高さを 240pt で測る（ホームの今日の一枚と同じやり方）。SE 相当・タグ 6 個はスクロールせずに収まり、写真は約 4 割。文字サイズ XXX Large 以上はスクロールする版になり、写真を 240pt で止めてジャンルとタグがなるべく見えるようにする
- `TagChipView` は中身を変えずに移した（仕分けのプレビューは移す前後でファイルが 1 バイトも違わない）。`TagAddChipView` のプレビューを `TagChipView.swift` に置いた
- プレビュー用のコンテナ `HomePreviewData.makeTaggedContainer(tags:)` を足した（タグを付けた「食べ物」の記録 1 件だけ）
- タグの一覧のプレビューは、シートで出すと静止画がシートの出る前になるので、中身をそのまま出す
- （レビュー 1 周目）`RecordStore.setTags` で、今の `tags` にある知らないキーを消さずにうしろに残すようにした。画面は知らないキーを除いた `tagValues` から一覧を作って書くので、そのままだと知らないキーが消えていた（`docs/data-model.md` の「知らないキーは表示しない（落とさない）」）。仕分けの経路も同じ関数なので一緒に直る
- （レビュー 2 周目）`FlowLayout` で幅を超える子を幅で止める直しは、レイアウトが報告する幅を変えておらず効いていなかったので戻した。今のタグ名・文字サイズの上限では起きないので、タグ名を増やすときに直す

## 前提・確認事項

- `Record.tags`・`tagValues`・`RecordStore.setTags`（重複を除き `Tag.allCases` の順に並べ直して書く）は #81 で実装済み。`RecordStoreTagsTests` もある。`Record` は変えない。`RecordStore` は `setTags` だけを直した（下の「実装で計画から変えたこと」）
- 詳細は `@Model` の `Record` を直接読んでいる（`record.isFavorite` など）。`setTags` で書くと、その場で描き直される。閉じて開き直しても残る（`ModelContext` の自動保存。今の「うまい」・ジャンルと同じ）
- 提案されたタグ（`suggestedTags`）は詳細では出さない。出すのは付いているタグ（`tags`）だけ（`docs/screen-design.md`）
- 詳細は `sheet` で開き、中は左右スワイプのページャー（`TabView` の `.page`）。シートからさらにシートを開ける（iOS 26 で問題ない）。一覧のシートを開いている間は、ページャーは動かない
- `project.pbxproj` は触らない。新しいファイルは同期フォルダに置くだけ
- 実機での確認は要らない（Issue のとおり。スワイプの取り合いを避ける要判断 3 の A なら、シミュレータとプレビューで足りる）。B を選んだときだけ、実機でページのめくりとの取り合いを見る

## 作り方の要点

### チップを共通にする（`Design/TagChipView.swift`、新規）

- 今は `Features/Sort/SortSuggestedTagsView.swift` の中に `private struct SortTagChipView` がある（付いている：白地に墨の線と −／外した：点線の枠と ＋。読み上げ「タグ 天ぷら」・選択中・「押すと外します／付けます」）
- これを `Design/TagChipView.swift` の `TagChipView`（`private` を外し、中身は変えない）に移し、仕分けと詳細とシートで使う。仕分けの見た目が変わらないことを、仕分けのプレビューのスクショで確かめる
- 「＋ タグ」「＋ タグを足す」のチップも同じファイルに `TagAddChipView` として置く（外した形と同じ点線の枠と ＋。文字は要判断 4）

### 折り返しの並べ方（`Design/FlowLayout.swift`、新規）

- SwiftUI の `Layout`（iOS 16〜）で、子を左から並べて、入らなければ次の行に送る小さなレイアウト。引数は `spacing`（横）と `lineSpacing`（縦）。`Theme.chipSpacing` を使う
- `sizeThatFits` で受け取った幅（`proposal.width`。`nil` なら無限とみなす）を超えたら改行し、行の高さの合計を返す。`placeSubviews` で同じ計算で置く
- 詳細の行とシートの中で使う

### 詳細のタグの行（`Features/Detail/RecordDetailTagsView.swift`、新規）

```swift
/// 記録の詳細の、付いているタグの行（機能27）。− で外す、＋ で一覧を開く。
struct RecordDetailTagsView: View {
    let tags: [Tag]              // record.tagValues（Tag.allCases の順）
    let onRemove: (Tag) -> Void
    let onAdd: () -> Void
}
```

- `FlowLayout` に `TagChipView(tag:isAttached: true)` を並べ、最後に `TagAddChipView`（0 個なら「タグを足す」、1 個以上なら「タグ」。要判断 4）
- まとまりとして読み上げ「付いているタグ」（`accessibilityElement(children: .contain)`）
- 文字サイズは仕分けと同じく `.xxxLarge` で止める（アクセシビリティサイズでチップが 1 行 1 個になり、写真が見えなくなるため）

### タグの一覧のシート（`Features/Detail/TagPickerView.swift`、新規）

```swift
/// タグの一覧から足す・外す（機能27）。押した時点で保存される。
struct TagPickerView: View {
    let record: Record
}
```

- 中で `RecordStore` を作り（`modelContext`・`photoStorage` を `@Environment` から。詳細と同じ）、チップを押すと `store.setTags(TagEditing.toggled(tag, in: record.tagValues), for: record)`
- `NavigationStack` の中に `ScrollView` → `TagKind` ごとに見出し（`kind.title`。「料理」「大分類」「系統」）と `FlowLayout` のチップ。付いている＝`isAttached: true`（要判断 5 の A）
- 右上の「完了」で `dismiss()`。`.presentationDetents([.medium, .large])`、`.presentationDragIndicator(.visible)`
- 料理を足しても、大分類・系統は足さない（要判断 6 の A）

### 付け外しの計算（`Features/Detail/TagEditing.swift`、新規。テストのため画面から出す）

```swift
enum TagEditing {
    /// `tag` が付いていれば外し、無ければ足した一覧。並びは気にしない（`setTags` が `Tag.allCases` の順に並べ直す）。
    static func toggled(_ tag: Tag, in tags: [Tag]) -> [Tag]
    /// 外した一覧。
    static func removing(_ tag: Tag, from tags: [Tag]) -> [Tag]
}
```

### 詳細への組み込み（`Features/Detail/RecordDetailView.swift`）

- `RecordDetailPageView` に `@State private var isTagPickerShown = false` を足す
- `content` の `VStack` の、`genreButtons` の下（要判断 1 の A）に `RecordDetailTagsView(tags: record.tagValues, onRemove: { store.setTags(TagEditing.removing($0, from: record.tagValues), for: record) }, onAdd: { isTagPickerShown = true })`
- `.sheet(isPresented: $isTagPickerShown) { TagPickerView(record: record) }`
- **縦に収まらないとき**：今の詳細はスクロールしない縦並びで、写真が `scaledToFit` で縮む。タグが 2〜3 行になると、小さい画面で写真がかなり小さくなる。プレビュー「SE 相当・タグ 6 個」で見て、写真の高さが画面の 4 割を切るなら、`content` を `ViewThatFits(in: .vertical) { 今の並び; ScrollView { 今の並び } }` にする（ホームと同じやり方）。縦のスクロールは、横のページャーとは取り合わない

## ステップ

1. `Kouiunodeiindayo/Design/TagChipView.swift`（新規）— `SortTagChipView` を移して `TagChipView` に、`TagAddChipView` を足す。`Features/Sort/SortSuggestedTagsView.swift` は `TagChipView` を使うように直すだけ（見た目は変えない）
   - 確認：ビルド。`SortSuggestedTagsView` のプレビュー 2 つと、`SortView` の「提案あり（ラーメン）」「提案あり・1つ外した」のスクショが、直す前と同じ（`.verification/84/preview-SortView-before.png`／`-after.png` を並べる）
2. `Kouiunodeiindayo/Design/FlowLayout.swift`（新規）— プレビューで、幅 375pt にチップ 8 個が 2〜3 行に折り返すこと
3. `Kouiunodeiindayo/Features/Detail/TagEditing.swift`（新規）と `KouiunodeiindayoTests/TagEditingTests.swift`（新規）
   - 付いていないタグ → 足される／付いているタグ → 外れる／空の一覧に足す／`removing` で無いタグを外しても変わらない
   - `RecordStore.setTags` と組み合わせて、足した結果が `Tag.allCases` の順で保存される（`TestStore` を使う。`Tag` は `Kouiunodeiindayo.Tag` と書く。Swift Testing の `Tag` とぶつかるため）
   - 確認：`docs/rules/verification.md` の 2
4. `Kouiunodeiindayo/Features/Detail/RecordDetailTagsView.swift`（新規）— プレビュー：0 個・3 個・8 個（折り返す）・文字サイズ XXX Large
5. `Kouiunodeiindayo/Features/Detail/TagPickerView.swift`（新規）— プレビュー：タグが 3 個付いた記録（`SampleData` のラーメンの記録）。押すと付け外しが変わる（キャンバスの Live で見る）
6. `Kouiunodeiindayo/Features/Detail/RecordDetailView.swift` — 行とシートを組み込む。プレビューを足す：「タグなし」「タグ 3 個」「SE 相当（375×667）・タグ 6 個」「SE 相当・文字サイズ XXX Large」。既存のプレビューは `HomePreviewData.makeManyContainer()` のまま
   - 要るなら `HomePreviewData` か `SampleData` に、タグが 6 個付いた仕分け済みの記録を足すコンテナを作る（`SampleData` はほかの画面のプレビューにも効くので、足すなら `HomePreviewData` 側に）
   - 確認：写真の大きさ（上の「縦に収まらないとき」）。スクショを `.verification/84/preview-RecordDetailView-*.png`
7. シミュレータで通し：一覧から記録を開く → ＋ でシート → 「餃子」「中華」を足す → 完了 → 行に出る → − で「中華」を外す → 閉じて開き直しても残っている → 左右にめくった先の記録でも同じ操作ができる → タグの無い記録で「＋ タグを足す」が出る。スクショ `01-詳細-タグなし.png`〜`05-開き直し.png` と `notes.md`
8. `docs/architecture.md` — フォルダ構成の `Detail/` に `RecordDetailTagsView.swift`・`TagPickerView.swift`・`TagEditing.swift`、`Design/` に `TagChipView.swift`（タグのチップ。仕分け・詳細・一覧のシートで共通）・`FlowLayout.swift`（折り返して並べるレイアウト）を足す。`Sort/SortSuggestedTagsView.swift` の説明の「チップ」を `TagChipView` を使う旨に
9. PR の本文に `docs/screen-design.md` の直し案（下）。編集はしない
10. コミットを分ける：`refactor: タグのチップを仕分けから共通の部品に移す (#84)`（ステップ 1）／`feat: 記録の詳細でタグを見て足す・外す (#84)`（2〜7）／`docs: 記録の詳細のタグの計画と構成を実装に合わせる (#84)`（8）

## ドキュメント（PR の本文に書く直し案。編集はこうせい）

- `docs/screen-design.md`「記録の詳細」の操作の表の「タグを付け直す」を「付いているタグが並ぶ。− で外す。＋ でタグの一覧を開き、押して足す・外す。その場で変わる。保存ボタンは無い」に。状態に「タグが無い（足す入口だけ出す）」
- `docs/data-model.md`・`docs/requirements.md`：変えない（要判断 6 が A のとき）

## 時間が足りないときに削る順

上から削る。「付いているタグが見える・足す・外す・開き直しても残る・0 個でも入口が分かる」（Issue の完成の条件）は残す。

1. 詳細の行の −（外すのはシートの中だけにする。要判断 2 の C に寄せる）
2. シートの見出し（種類ごとに分けず、`Tag.allCases` の順に 1 つの塊で並べる）
3. `FlowLayout`（シートは `LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))])`、詳細の行は付いているタグを「、」でつないだ文字にする）
4. チップを共通にする（ステップ 1）→ 詳細とシートには仕分けのチップを写した別の小さなビューを置く（見た目の二重管理になるので、あとで共通にする Issue を立てる）

## リスク

- **縦に収まらず写真が小さくなる**：「作り方の要点」の「縦に収まらないとき」の対応。プレビューの SE 相当で必ず見る
- **チップを移すときに、仕分けの見た目が変わる**：移すだけで中身は変えない。直す前後のスクショを並べて見る。#102・#103 のマージ後に作るので、`SortSuggestedTagsView` が変わっていたら、その版から移す
- **シートの中で `record` が消える**（シートを開いたまま、別の経路で記録が消されることは今のアプリには無い）。対応しない
- **`Tag` が Swift Testing の `Tag` とぶつかる**（#83 で既知）。テストでは `Kouiunodeiindayo.Tag`
- **ワイヤー集の「記録詳細の案」（A〜F）が決まると、並び全体が変わる**。この Issue のタグの行・シート・チップは部品として分けておくので、並びが変わっても置き直すだけで済む
- **`project.pbxproj` の未コミットの変更**が作業ツリーに残っていたら、コミットに混ぜない。`git add` はファイルを指定する

## 完成の確認方法

- `docs/rules/verification.md` の 1（ビルド）・2（テスト。`TagEditingTests` と既存のテストが全部通る）
- プレビュー：ステップ 1・2・4・5・6 のスクショ。仕分けのチップの見た目が変わっていない
- シミュレータ：ステップ 7 の通し。Issue の完成の条件の 3 つ（見える・足す外すが残る・0 個でも入口が分かる）はここで見る
- 実機：要らない（Issue のとおり。要判断 3 で B を選んだときだけ、ページのめくりとの取り合いを実機で見る）
- `git status` で `project.pbxproj` と `Config/Local.xcconfig` がコミットに入っていない
