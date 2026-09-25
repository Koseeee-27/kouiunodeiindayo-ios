import SwiftUI

/// 設定。ホーム右上のアイコンから `sheet` で開く。
/// 要素は `docs/screen-design.md` の「設定」が正。今は機能22（プライバシーポリシー・お問い合わせ・バージョン）だけを置く
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // 外部ページは Safari に渡す（アプリ内ブラウザは使わない）
                    if let url = AppLinks.privacyPolicy {
                        externalLink("プライバシーポリシー", destination: url)
                    }
                    if let url = AppLinks.support {
                        externalLink("お問い合わせ", destination: url)
                    }
                    LabeledContent("バージョン", value: Self.version)
                } header: {
                    // 下の `.font` が見出しにも効くので、見出しは小さい文字を明示する
                    Text("このアプリについて")
                        .font(Theme.font(.footnote))
                }
            }
            // `List` の行は標準の文字で描かれるので、アプリの文字をここでも当てる
            .font(Theme.font(.body))
            // `List` の標準の地を消してから、アプリの地に差し替える
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// 外部に出る行だと分かるよう、右に矢印を付ける
    private func externalLink(_ title: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint("Safari で開く")
    }

    /// `1.0 (1)` の形。取れなかったときは `-`
    private static var version: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String,
            let build = info?["CFBundleVersion"] as? String
        else { return "-" }
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView()
}
