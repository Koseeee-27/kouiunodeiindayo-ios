# 0001: Swift + SwiftUI で作る

- 状態：採用
- 日付：2026-09-21

## 決めたこと

iPhone アプリを Swift + SwiftUI のネイティブ開発で作る。UIKit は、SwiftUI に無い部品（標準カメラ画面）を包むところだけで使う。

## 理由

- アプリの核（起動したらすぐカメラ、スワイプの手触り、効果音、端末内保存）が、すべて Apple 純正の API で完結する
- 将来の拡張候補（端末上の AI で写真に一言を付ける）で使う Vision / Foundation Models を直接呼べる
- 「起動時にタイトルを出す」とアプリアイコンは決定済みの要件で、その確認とデモには、どの選択肢でも結局 Xcode でのビルドと署名が要る。別の層を挟むと、覚える道具が二重になる
- 開発者2人とも Apple silicon の Mac と iPhone を持っていて、Xcode 27 を使える

## 比べた選択肢

| 選択肢 | 外した理由 |
|---|---|
| React Native + Expo | 初日は Expo Go で Mac 無しに実機確認できるが、アイコン・起動画面の確認とデモには Xcode のビルドが要る。端末上の AI を使うには橋渡しのコードが要る。直近半年で互換性の無い変更が多い |
| Flutter | Dart を2人とも新しく学ぶことになる。Mac も必須で、Expo より利点が無い |
| Capacitor（Web 技術） | 縦書きは CSS で楽だが、一番こだわるスワイプの操作感と独自カメラが弱い |
| PWA | iOS では、1週間開かないと保存データが消える制限などがあり、写真の記録に使えない |

縦書きの日本語は、Web 系以外のどの選択肢にも標準機能が無く、差にならなかった。

## 影響・注意

- 2人ともモバイル開発が初めて。Swift、SwiftUI の状態管理、署名を同時に学ぶことになる
- Xcode 27・iOS 27 は 2026-09-14 に出たばかりで、AI の知識や Web の記事が古いことがある。書き方の決まりは `docs/rules/swift.md`
- 縦書きの扱いは `docs/rules/swift.md` の「操作と見た目」

## 出典

- https://developer.apple.com/swiftui/
- https://developer.apple.com/support/xcode/
- https://expo.dev/changelog/sdk-57
- https://docs.flutter.dev/platform-integration/ios/setup
- https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide
