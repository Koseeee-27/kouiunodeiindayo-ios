# 実装計画: 仕分けの画面に、提案されたジャンル（点線の囲み）とタグ（− つきのチップ）を出す

## 概要

仕分けの画面で、提案されたジャンルのラベルを赤い点線で囲み、提案されたタグをカードの下に − つきのチップで並べる。チップを押すと外れ（点線の枠と ＋）、もう一度押すと付く。ジャンルを付けて次に進むとき、そのとき付いているタグを `RecordStore.setTags` で記録に書く。対応する Issue：#83（親 #86）。対応する機能：`docs/requirements.md` の機能26（ジャンルとタグの提案）・機能27（タグを付ける）の仕分けの部分。

要素と操作は `docs/screen-design.md`「仕分け」、書き込みの決まりは `docs/architecture.md`「書くとき」の「タグを変える」、提案が届く流れは同じく「提案（機能26）の流れ」が正。見た目はワイヤー集「タグの見せ方」の 1c（赤い点線で囲む）・2b（− つきのチップ。9/26 決定）。この計画はそれを画面の部品と状態に落としたもの。

## 前提・確認事項

- #81（`Record.suggestedGenreValue`・`suggestedTagValues`・`RecordStore.setTags`）と #82（問い合わせ。`SuggestionService`・`SuggestionMock`）は main に入っている。`SortView` はすでに、開いたときに `suggestedAt == nil` の写真を問い合わせている
- 提案は `RecordStore.saveSuggestion` が 1 回だけ書く（問い合わせ済みなら書かない）。**画面に出たあとで提案が差し替わることはない**。届く前 → 届いた、の 1 回の変化だけを考えればよい
- `Record` は `@Model`（中身の変化を SwiftUI が追える）なので、提案が保存されると、`body` で `record.suggestedGenreValue` などを読んでいるビューは自動で描き直される。問い合わせの完了を画面に知らせる仕組みは要らない
- `SampleData.makePreviewContainer()` の仕分け待ち 1 件には、ラーメンの提案（食べ物・ラーメン・麺類・中華）が保存済み（`SampleData.swift` の 40 行目）。既存の `SortView` のプレビュー「1枚」「複数枚」などにも、この Issue の見た目が出るようになる
- Worker が返すタグは、料理・大分類・系統を合わせて 0〜5 個くらい（ラーメンの例は ramen・noodles・chinese・japanese の 4 個）。ワイヤーは 3 個で描いているが、4〜5 個でも崩れないようにする
- 仕分けを ✕ で抜けたときは、外したタグを記録に書かない（タグを書くのは「ジャンルを付けて次に進むとき」だけ。`docs/screen-design.md`）。仕分け待ちに残った写真は、次に開いたときにまた全部付いた状態で出る
- `project.pbxproj` は触らない。足すファイルは同期フォルダ（`Kouiunodeiindayo/`・`KouiunodeiindayoTests/`）の中に置くだけ
- 同じ画面を触る #56（並び順の切り替え）・#22（効果音とアニメーション）・#63（仕分け待ちの入口）とは同時に進めない（#86「ほかの Issue とぶつかりやすいところ」）。先にマージされたほうに合わせる

## 決めたこと（2026-09-27 こうせい確認。計画のときの要判断は全部おすすめのほうに決めた）

1. **点線は赤で描く。** `Theme.swift` の冒頭の「赤はハンコ・スタンプだけに使う」に、例外として「提案のしるし（点線の囲み）」を書き足す。点線の色は `Theme.accent` を指す別名（`Theme.suggestionMark`）にする。墨の点線だと、ラベルの墨の線と見分けにくいため
2. **点線は、吹き出しの形（尻尾も含む）に沿わせ、4pt 外側に描く。** 今のラベルの形（`LabelBubbleShape`）をそのまま外側に広げて点線で描く。ワイヤーの `outline-offset: 3px` に近い。角丸の四角で囲むと、尻尾だけ囲みの外に出て見える
3. **タグの行は、提案が無いときも 1 行分を空けておく。** 提案は写真が出たあとに届く（撮った直後は 1 秒前後遅れる）。届いたときに行が現れてカードが縮むと、指で動かしている最中のカードが跳ねるため。提案が無い写真では、カードの下が 1 行分空くだけ
4. **チップの文字は `.xxxLarge`（アクセシビリティサイズの手前）で止め、1 行に入りきらないときは横にスクロールする（折り返さない）。** ジャンルのラベルも同じ理由で `.large` で止めている。折り返すと行が 2〜3 段になり、カードが小さくなって写真が見えにくくなるため
5. **VoiceOver の読み上げ：**
   - 提案されたジャンルのラベル：今のラベル「食べ物にする」はそのまま、値（`accessibilityValue`）に「提案」を足す →「食べ物にする、提案、ボタン」
   - チップ：ラベルは「タグ 天ぷら」。付いているときは選択中（`.isSelected`。「う、うまい」と同じやり方）。ヒントは付いているとき「押すと外します」、外したとき「押すと付けます」
   - チップの並び全体を「提案されたタグ」というまとまりにする（`accessibilityElement(children: .contain)` ＋ ラベル）

6. **（実装で変えたこと）タグの行は、`SortView` の `VStack` の最後ではなく、`SortCardStackView` の下のラベルのすぐ下に置く。** `SortView` の `VStack` の最後に置くと、大きい画面（iPhone 18 Pro）でタグの行がカードから離れて画面の下端に出た（ワイヤーは「カードの下」）。`SortCardStackView` を、下のラベルの下に置くビュー（`belowCard`）を受け取る汎用の型にし、`SortView` がそこに `SortSuggestedTagsView` を渡す。上下の余白は、上のラベルの高さ・下のラベルとタグの行を合わせた高さを、それぞれ `onGeometryChange` で測って空ける。汎用の型は `static let` を持てないので、`SortCardStackView` の定数は計算で返す形（`static var 〜: CGFloat { 8 }`）に変えた
7. **（実装で変えたこと）テストでは `Tag` をモジュール名つき（`Kouiunodeiindayo.Tag`）で書く。** Swift Testing にも `Tag` という型があり、型を書くところでは曖昧になる

## 画面の状態（どれでも仕分けはいつも通りできる）

| 状態 | `Record` の値 | ジャンルのラベル | タグの行 |
|---|---|---|---|
| 提案が届く前 | `suggestedAt == nil` | 点線なし | 空（高さは空けておく。要判断 3） |
| 通信できない・時間切れ・Worker 未設定 | `suggestedAt == nil` のまま | 点線なし | 空（届く前と同じ。読み込み中の印は出さない。`docs/screen-design.md`「届かなければ出さない」） |
| 提案なし（自信が低い） | `suggestedAt` あり・`suggestedGenre == nil`・`suggestedTags` 空 | 点線なし | 空 |
| ジャンルだけ・タグだけの提案 | どちらか片方 | あるほうだけ出す | 同左 |
| 提案がある | 両方 | 提案されたラベルを点線で囲む | 全部付いた状態のチップ |
| 仕分け中に届いた（ドラッグ中を含む） | `nil` → 値あり | その場で点線が付く（0.15 秒で現れる） | その場でチップが現れる。カードの大きさは変わらない |
| ドラッグ中 | — | 点線は強調（`.strong` の拡大・`.weak` の薄さ）と一緒に拡大・薄くなる。点線自体は消さない | そのまま。ドラッグ中は押しても反応しないようにはしない（カードの外なので取り違えない） |
| カードが飛んでいる間 | — | 飛ばした写真の点線のまま | 押せない（`isCommitting` の間は `allowsHitTesting(false)`） |

## 作り方の要点

### ジャンルの点線（`SortGenreLabelView`）

- 引数に `isSuggested: Bool` を足す。`true` のとき、吹き出しの形を 4pt 外側に広げた線を、`Theme.suggestionMark`（赤）の点線（太さ `Theme.lineWidthSuggestion` = 2、点線の間隔 `[5, 4]` くらい）で描く
- `LabelBubbleShape` の `inset` に負の値を入れると外側に広がる形になる（今は線の太さの半分だけ内側に描くのに使っている）。`background` の中の 2 つ（塗り・墨の線）の後ろに、点線の `shape` を `overlay` で重ねる。外側に描くので、ラベルの大きさ（押せる範囲・`.padding`）は変えない。はみ出しは `.padding` を足さずに描く（左右のラベルの位置がずれないように）
- 点線はスワイプ中の強調とは別の見え方（`docs/screen-design.md`）：強調は「墨の地に白い字・1.15 倍」、提案は「赤い点線」。重なっても両方見える
- `SortCardStackView.genreLabel` で `isSuggested: records.first?.suggestedGenreValue == direction.genre` を渡す。飛んでいる間も `records.first` は飛ばしている写真のまま（`onSort` のあとで先頭が変わる）なので、別の写真の点線が一瞬出ることはない
- `.animation(.easeOut(duration: 0.15), value: isSuggested)` で、届いたときにふわっと出す

### タグのチップ（新しいファイル `Features/Sort/SortSuggestedTagsView.swift`）

- 引数：`tags: [Tag]`（提案されたタグ。`record.suggestedTagValues`）、`removed: Set<Tag>`（外したタグ）、`isEnabled: Bool`（飛んでいる間は `false`）、`onToggle: (Tag) -> Void`
- 1 行の横並び（`ViewThatFits(in: .horizontal)` で、入りきるときは `HStack` をそのまま真ん中に、入りきらないときだけ `ScrollView(.horizontal)` の中の `HStack` にする。スクロールのインジケーターは出さない）。行の高さは、提案が無いときも 1 行分を空ける（決めたこと 3。空のときは見えないチップを 1 つ置いて高さを決め、読み上げからは隠す）
- チップ 1 つ（ワイヤー 2b）：
  - 付いている：白地（`Theme.surface`）・墨の線（`Theme.line`、太さ `Theme.lineWidthBubble`）・カプセル形・墨の字・右に小さな丸の中の「−」（SF Symbols の `minus`）
  - 外した：地なし・`Theme.textSecondary` の点線の枠・同じ色の字・丸の中は「＋」（`plus`）
  - 文字は `Theme.font(.subheadline, bold: true)`。`.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`（決めたこと 4）
  - 見た目の高さはワイヤーどおり小さめ（約 32pt）、押せる範囲は上下に広げて `Theme.minTapHeight`（44pt）以上にする（`contentShape` と `frame(minHeight:)`）
  - 付け外しは `.animation(.easeOut(duration: 0.15))`。振動・効果音は付けない（#22 の範囲）
- 足す `Theme` の定義：`suggestionMark`（赤。決めたこと 1）、`lineWidthSuggestion`、`suggestionDash`（点線の間隔）、`chipSymbolBackground`（−・＋ の丸の地。`textSecondary` を薄くしたもの）、`chipSymbolSize`・`chipPadding`・`chipInnerSpacing`・`chipSpacing`（チップの大きさと間隔）、`sortBelowLabelSpacing`（下のラベルとタグの行の間）。画面に色や数値を直書きしない
- 読み上げは決めたこと 5 のとおり

### 外したタグの持ち方と、書き込みの流れ

- `SortView` に `@State private var removedTags: [UUID: Set<Tag>] = [:]`（記録の `id` ごとに、外したタグ）を持つ
  - 「付いているタグ」ではなく「外したタグ」を持つ。提案が後から届いても、何もしなくても全部付いた状態で出る（届いた時点で初期値を入れ直す処理が要らない）
  - 記録の `id` ごとに持つので、#56 で並び順を切り替えて先頭が入れ替わっても、外した状態が別の写真に移らない
  - `Record` には書かない（書くのは次に進むときだけ）。仕分けを抜けたら捨てる（`@State` なので画面を閉じれば消える）
- チップを押したら `SortTagSelection.toggled` で `removedTags[record.id]` に入れる／抜く（ほかの写真の分は変えない）。写真は次に進まない。飛んでいる間（`isCommitting`）は受け付けない（読み上げからのダブルタップも。ジャンルのラベルの `commit` と揃える）
- 付いているタグを出す関数を 1 つにまとめる（新しいファイル `Features/Sort/SortTagSelection.swift`）

  ```swift
  /// 仕分けで付いているタグ。提案されたタグから、外したものを除く（並びは提案の順のまま）
  enum SortTagSelection {
      static func attached(suggested: [Tag], removed: Set<Tag>) -> [Tag]
      /// チップを押したとき。`id` の写真の分だけ切り替えた辞書を返す（`initial` はプレビュー用の初期値）
      static func toggled(_ tag: Tag, for id: UUID, in removedTags: [UUID: Set<Tag>], initial: Set<Tag> = []) -> [UUID: Set<Tag>]
      /// 次に進むときの書き込み。タグを先に書いてからジャンルを付ける（ジャンルを付けると `@Query` から消えるため）
      static func commit(_ record: Record, genre: Genre, removed: Set<Tag>, store: RecordStore)
  }
  ```

- `SortView` の `onSort` を `SortTagSelection.commit(record, genre: genre, removed: removedTags[record.id] ?? previewRemovedTags, store: store)` に差し替える。`commit` の中は `store.setTags(attached(…), for: record)` → `store.setGenre(genre, for: record)` の順（`docs/architecture.md`「タグを変える」：「仕分けでジャンルを付けて次に進むとき（そのとき付いているタグで書く）」）
  - 提案が届く前・提案なしのときは `setTags([])` になる（仕分け待ちの記録の `tags` は空なので、変わらない）
  - スワイプでもラベルを押しても、`SortCardStackView` の `commit` → `onSort` の同じ道を通る（スワイプとタップで同じ関数。`docs/rules/swift.md`）
  - 書いたあと `removedTags[record.id]` は消す
- `SortCardStackView` には、点線のために `records.first` の提案を読む 1 行と、下のラベルの下に置く `belowCard`（タグの行）を足す（決めたこと 6）。`onSort` の形は変えない（中身が変わるだけ）

### 画面の配置（`SortView`・`SortCardStackView`）

- タグの行は、`SortCardStackView` の下のラベルのすぐ下に置く（決めたこと 6）。`SortView` が `SortSuggestedTagsView` を作って `belowCard` に渡す。タグの行は `records.first` の提案を出す
- **下のラベルとタグの行が、上の行や画面の外にかぶらないようにする。** 上下のラベル（と、下のタグの行）はカードの縁の外に `overlay` ではみ出して描いていて、`SortCardStackView` の枠の高さには入っていない。そのままだと狭い画面（幅 375pt・高さ 667pt）で、上のラベルが上の行に、下のタグの行が画面の外にかぶる。上のラベルの高さと、下のラベル＋タグの行の高さを `onGeometryChange` で測り、その分を枠の上下に空けてカードのほうを小さくする
- 右上の「う、うまい」・上のラベル・スタンプの位置は変えない

## ステップ

1. `Design/Theme.swift` — 点線とチップの定義を足す（上の「足す `Theme` の定義」）。冒頭の「赤は〜だけ」を決めたこと 1 のとおり、例外に「提案のしるし（点線）」を書き足す / ビルドが通る
2. `Features/Sort/SortTagSelection.swift`（新規）— `attached`・`commit` / 下のテストで確かめる
3. `KouiunodeiindayoTests/SortTagSelectionTests.swift`（新規）— `TestStore` を使う。確かめること：
   - 外したタグは `tags` に入らず、残りは一覧の順で入る
   - 全部外すと `tags` が空
   - 提案が届く前（提案なし）に進むと `tags` は空のまま
   - `commit` のあと `genre` が付き、`suggestedTags` は変わらない
   - 外したタグを戻す（`removed` から抜く）と、また入る
   - `toggled`：写真 A で外しても写真 B は全部付いたまま／戻すとまた入る／2 件を違うタグで仕分けると記録ごとの `tags` が別々（次の写真に持ち越さない）
4. `Features/Sort/SortGenreLabelView.swift` — `isSuggested` と点線、読み上げの値。ファイルの最後に、4 つの向き × 提案あり・なし × 強調 3 種を並べたプレビューを足す / プレビューで見る
5. `Features/Sort/SortSuggestedTagsView.swift`（新規）— チップの行と読み上げ。プレビュー：全部付いている／1 つ外した／5 個（入りきらない）／空（高さだけ）／文字サイズ `.accessibility5`（上限で止まるか）
6. `Features/Sort/SortCardStackView.swift` — `genreLabel` に `isSuggested` を渡す。`belowCard` を下のラベルの下に置き、上下の余白を空ける（上の「画面の配置」） / 既存のプレビュー「幅 375pt・文字サイズ X Large」で、上のラベルが上の行に、下のラベルがタグの行にかぶらない
7. `Features/Sort/SortView.swift` — `removedTags`、`SortSuggestedTagsView` を `belowCard` に渡す、`onSort` を `SortTagSelection.commit` に。プレビューを足す（下の「プレビュー」）
8. `docs/architecture.md` — フォルダ構成の `Sort/` に `SortSuggestedTagsView.swift`・`SortTagSelection.swift` の 1 行ずつを足す。`SortGenreLabelView` の説明に「提案の点線」を足す
9. 検証（`docs/rules/verification.md` の 1〜3）→ `.verification/83/` にスクショと `notes.md`（実機の確認手順もここに書く）

## プレビュー（`SortView` に足す。静止画はすぐ撮られるので `.immediate` を使う）

| 名前 | 中身 | 見るところ |
|---|---|---|
| 提案あり（ラーメン） | `SortPreviewData.makeManyUnsortedContainer()` ＋ `SuggestionMock.ramen.immediate` | 上の「食べ物」が点線、下にチップ 3 つ |
| 提案あり・1 つ外した | 同上 ＋ 外した状態を渡す（下の注） | 外したチップが点線と ＋ |
| 提案なし | `SuggestionMock.noSuggestion.immediate`（サンプルの提案済み 1 件は除くため、提案の無い仕分け待ちだけのコンテナを `SortPreviewData` に足す） | 点線なし・チップなし・カードの大きさが「提案あり」と同じ |
| 通信できない | `SuggestionMock.disabled` ＋ 同じコンテナ | 同上 |
| 後から届く | `SuggestionMock.ramen`（0.3 秒待つ版） | 静止画では「届く前」になる。キャンバスで動かして、届いたときにカードが跳ねないかを見る |
| ドラッグ途中・提案あり | `dragOffset` ＋ ラーメン | 上に向けたとき、強調と点線が両方見える |
| 幅 375pt・文字サイズ最大・提案あり | `.frame(width: 375, height: 667)`・`.dynamicTypeSize(.accessibility5)` | ラベルとタグの行が重ならない・チップが上限で止まる・横にスクロールできる |

注：外した状態を外から渡すため、`SortView.init` に、プレビュー用の引数 `removedTags: Set<Tag> = []`（先頭の写真に当てる）を足す。今の `dragOffset` と同じやり方で、`@State` の初期値を `init` の中で代入しない（`docs/rules/swift.md`。`previewRemovedTags` として `let` で持ち、`removedTags[id] ?? previewRemovedTags` で読む）。

## リスク

- **狭い画面でカードが小さくなる。** タグの行（約 44pt ＋ 間隔）と上下のラベルの分だけ、幅 375pt の機種ではカードが今より低くなる。スワイプの距離のしきい値（`SwipeDirection`）は pt で決まっているので手触りは変わらないはずだが、実機で確かめる。小さくなりすぎるなら、タグの行とカードの間隔・下のラベルとの間隔を詰める
- **チップの横スクロールとスワイプの取り違え。** チップの行はカードの外なので、カードのドラッグとは別の場所。ただ、チップの行から指を動かし始めてカードに入る操作では、スクロールが先に取るのでカードは動かない（今と同じ：カードの外から始めたドラッグはカードを動かさない）。実機で「チップを押したつもりでカードが飛ぶ」「カードを払ったつもりでチップが切り替わる」が無いかを見る
- **点線の赤が「うまい」のハンコと混ざる。** 上のラベルと右上の「う、うまい」は近い。上のラベルはカードの外、ハンコはカードの中なので重ならないが、赤が 2 か所に出る。スクショで見て、うるさければ墨の点線に変えるかを相談する
- **提案が届いた瞬間のちらつき。** 点線とチップは 0.15 秒で現れるだけにする。カードの大きさ・位置は変えない（決めたこと 3）
- **#56 とのぶつかり。** #56 が先にマージされたら、`SortView` の並び順の切り替えの上に足す。外した状態は `id` ごとなので、並び替えても壊れない
- **`suggestedTagValues` の知らないキー。** 知らないキーは `Record` 側で捨てているので、チップには出ない（落ちない）

## 完成の確認方法

- テスト：`SortTagSelectionTests` が通る（外したタグは記録に入らない、を含む）
- プレビュー：上の表のすべてをスクショにして `.verification/83/` に置く。`SortGenreLabelView`・`SortSuggestedTagsView` のプレビューも。文字サイズ最大（`.accessibility5`）で、ラベル・タグの行・上の行・「う、うまい」が重ならない
- Issue の完成の条件との対応：
  - 提案がある／ない／あとから届く、のどれでも仕分けがいつも通りできる → プレビュー 3 種 ＋ 実機
  - チップを押してもスワイプと取り違えない → 実機
  - 外したタグは記録に入らない → テスト
  - 読み上げで、提案されたジャンルとタグの付け外しが分かる → 実機（VoiceOver）。プレビューでは `accessibilityLabel`・`Value`・`Hint` をコードで確認
- **実機での確認（要る。人が行う）**。`.verification/83/notes.md` に手順を書く：
  1. `Config/Local.xcconfig` に Worker の URL と合言葉がある状態で、撮る → 仕分けで、1 秒前後で点線とチップが出る。出たときにカードが跳ねない
  2. 仕分け待ちが複数ある状態で入口から開き、次々と仕分ける。スワイプの手触り（どこまで動かせば飛ぶか・飛び方・後ろのカードのせり上がり）が今までと変わらない
  3. チップを何度か押す：写真は次に進まない、カードは動かない。チップの行から指を払っても写真は飛ばない
  4. チップを 1 つ外してから上にスワイプ → 次の写真へ。外した状態が次の写真に持ち越されない
  5. 機内モードで撮る → 仕分け：点線もチップも出ず、仕分けはいつも通り
  6. VoiceOver をオンにして仕分け：提案されたラベルで「提案」、チップで「タグ 天ぷら、選択中、押すと外します」のように読まれ、ダブルタップで付け外しできる。ラベルをダブルタップして仕分けられる
  7. 幅の狭い機種があれば（SE・mini）、ラベルとタグの行が重ならない
  8. 外したタグが記録に入っていないこと：記録の詳細でタグを見られるのは #84 なので、#84 が入る前はテストで確かめた扱いにし、#84 が入ったら詳細で見る
