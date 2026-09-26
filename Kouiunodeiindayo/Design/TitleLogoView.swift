import SwiftUI

/// 画面左上の見出しに置くタイトルロゴ。ホームと一覧で同じものを使う。
/// 素材は `Assets.xcassets/TitleLogo`（SVG）。読み上げでは、画像ではなくアプリ名の見出しとして読まれる。
struct TitleLogoView: View {
    /// ロゴの高さ。幅は元の比率で決まる。利用者の文字サイズ設定に合わせて大きくなる
    @ScaledMetric(relativeTo: .title2) private var height: CGFloat = 44

    var body: some View {
        Image("TitleLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            // 見出しの左端より、ほんの少し左に寄せる（レイアウトの幅は変えない）。置く側に 4pt 以上の左の余白が要る
            .offset(x: -4)
            // 読み上げはアプリ名。Info.plist の表示名と同じ文言にそろえる
            .accessibilityLabel("こういうのでいいんだよ")
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    TitleLogoView()
        .padding()
        .background(Theme.background)
}
