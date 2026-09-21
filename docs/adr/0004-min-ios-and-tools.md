# 0004: iOS 26 以上、Xcode 27、外部ライブラリ無し、同期フォルダ

- 状態：採用
- 日付：2026-09-21

## 決めたこと

- 対応 OS は iOS 26 以上。iPhone のみ、縦画面のみ
- 開発は Xcode 27（Swift 6.4）。2人とも同じメジャーバージョンに揃える
- 外部ライブラリ（Swift Package）は MVP では使わない
- プロジェクトは Xcode の同期フォルダ（フォルダの中身を Xcode が自動で認識する形式）で作る。XcodeGen や Tuist などの追加ツールは入れない
- AI には `project.pbxproj`（Xcode のプロジェクトファイル）を編集させない
- 署名は各自の無料の Apple ID で行い、個人ごとの値（Team ID、Bundle ID の接頭辞）は git に入れない `Config/Local.xcconfig` に書く

## 理由

- 開発者の Mac は macOS 27。Xcode 26 系の対応 macOS は 26.x までとされていて、実質 Xcode 27 しか使えない
- チームの iPhone は iOS 27。下限を iOS 26 にしても困らない。iOS 27 だけの API を使う箇所が `if #available` で明示されるので、AI が存在しない API を書いたときに気づきやすい
- Xcode 27 は出たばかりで、外部ライブラリが対応しているかが分からない。要件は Apple 純正の API だけで満たせる
- 同期フォルダなら、ファイルを足してもプロジェクトファイルが変わらない。2人で git を使うときの衝突と、AI がプロジェクトファイルを壊す事故が減る
- 無料の Apple ID では、2人が同じ Bundle ID を使うと署名が衝突する

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| 対応を iOS 27 以上にする | SwiftData の新機能などが使えるが、AI が iOS 27 の API を正しく知らない可能性が高い |
| XcodeGen / Tuist | プロジェクトファイルを git から外せるが、覚える道具が増える。同期フォルダで足りる |
| 有料の Apple Developer Program | デモだけなら不要。承認に数日かかった報告があり、本番に間に合わない可能性がある。App Store に出すと決めたら入る |

## 影響・注意

- 無料の Apple ID には、7日で使えなくなるなどの制限がある。制限と、デモ機の決め方は `docs/setup.md`
- ライブラリを足したくなったら、先に ADR を書く

## 出典

- https://developer.apple.com/support/xcode/
- https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- https://developer.apple.com/support/compare-memberships/
- https://developer.apple.com/help/account/access/roles/
- https://blakecrosley.com/guides/ios-agent-development
- https://www.tatejennings.com/blog/making-claude-code-work-for-ios-development
