import SwiftUI
import UIKit

/// カメラの許可を断られた・制限されているときに、標準カメラの代わりに出す案内（機能9）。
/// 設定アプリを開く・アルバムから選ぶ・ホームへ戻る、ができる。画面の切り替えは呼び出し側（`CameraFlowView`）が行う。
struct CameraAccessGuideView: View {
    /// true ならスクリーンタイムなどで制限されている用の文言、false なら断られた用の文言。
    let isRestricted: Bool
    let onPickFromLibrary: () -> Void
    let onGoHome: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(Theme.font(.largeTitle))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    Text("カメラが使えません")
                        .font(Theme.font(.title2, bold: true))
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        // 「設定アプリで『カメラ』をオンにすると撮れます」を、SE の幅でも1行に収める大きさ
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    // 制限はこのアプリの設定では外せないので、制限されているときはアルバムのほうを目立たせる
                    wideButton("設定を開く", style: isRestricted ? .normal : .prominent) {
                        openSettings()
                    }
                    .accessibilityHint("設定アプリに移ります")

                    wideButton("アルバムから選ぶ", style: isRestricted ? .prominent : .normal) {
                        onPickFromLibrary()
                    }

                    // 文字だけだと押せると分かりにくいので、ほかの2つと同じ形の枠線だけのボタンにする
                    wideButton("ホームへ", style: .outlined) {
                        onGoHome()
                    }
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        // 中身が短いときは画面の縦の真ん中に置く。長いときは上から並べてスクロールさせる
        .defaultScrollAnchor(.center, for: .alignment)
    }

    private var message: String {
        if isRestricted {
            // 文の区切りで改行する。ほかの画面の文言に合わせて、最後の「。」は付けない
            "スクリーンタイムなどでカメラが制限されているため、撮れません。\nアルバムから選んで記録できます"
        } else {
            "カメラへのアクセスがオフになっています。\n設定アプリで「カメラ」をオンにすると撮れます"
        }
    }

    private enum WideButtonStyle {
        /// 塗りつぶし（`.borderedProminent`）。目立たせる1つだけ
        case prominent
        /// うすい地（`.bordered`）
        case normal
        /// 枠線だけ。一番控えめ
        case outlined
    }

    /// 横いっぱいのボタン。
    @ViewBuilder
    private func wideButton(_ title: String, style: WideButtonStyle, action: @escaping () -> Void) -> some View {
        let label = Text(title)
            .frame(maxWidth: .infinity)
        // `Button(action: action)` と関数を直接渡すと、Xcode 27 のプレビューがビルドに失敗する。クロージャで包むと通る
        switch style {
        case .prominent:
            Button {
                action()
            } label: {
                label
            }
            .buttonStyle(.borderedProminent)
        case .normal:
            Button {
                action()
            } label: {
                label
            }
            .buttonStyle(.bordered)
        case .outlined:
            // `.bordered` と同じ高さ・形にして、地を消して枠線を引く。文字は強調色ではなく、ふつうの文字の色にする
            Button {
                action()
            } label: {
                label
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.bordered)
            .tint(.clear)
            .overlay {
                Capsule()
                    .strokeBorder(Theme.line, lineWidth: Theme.lineWidthThin)
                    .allowsHitTesting(false)
            }
        }
    }

    private func openSettings() {
        // このアプリの設定画面が開く
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview("断られた") {
    CameraAccessGuideView(isRestricted: false, onPickFromLibrary: {}, onGoHome: {})
}

#Preview("制限されている") {
    CameraAccessGuideView(isRestricted: true, onPickFromLibrary: {}, onGoHome: {})
}
