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
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("カメラが使えません")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    // 制限はこのアプリの設定では外せないので、制限されているときはアルバムのほうを目立たせる
                    wideButton("設定を開く", isProminent: !isRestricted) {
                        openSettings()
                    }
                    .accessibilityHint("設定アプリに移ります")

                    wideButton("アルバムから選ぶ", isProminent: isRestricted) {
                        onPickFromLibrary()
                    }

                    Button("ホームへ") {
                        onGoHome()
                    }
                }
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        // 中身が短いときは画面の縦の真ん中に置く。長いときは上から並べてスクロールさせる
        .defaultScrollAnchor(.center, for: .alignment)
    }

    private var message: String {
        if isRestricted {
            "スクリーンタイムなどでカメラが制限されているため、撮れません。アルバムから選んで記録できます。"
        } else {
            "カメラへのアクセスがオフになっています。設定アプリで「カメラ」をオンにすると撮れます。"
        }
    }

    /// 横いっぱいのボタン。目立たせる1つだけ `.borderedProminent`、ほかは `.bordered`。
    @ViewBuilder
    private func wideButton(_ title: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        // `Button(action: action)` と関数を直接渡すと、Xcode 27 のプレビューがビルドに失敗する。クロージャで包むと通る
        let button = Button {
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        if isProminent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
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
