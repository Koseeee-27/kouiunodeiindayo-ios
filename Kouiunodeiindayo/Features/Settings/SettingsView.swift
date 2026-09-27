import SwiftUI

/// 設定。ホーム右上のアイコンから `sheet` で開く。
/// 要素は `docs/screen-design.md` の「設定」が正。今は機能19（写真アプリにも保存する）・機能24（効果音の音量）・
/// 機能22（プライバシーポリシー・お問い合わせ・バージョン）を置く
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PhotoLibrarySaver.storageKey) private var savesToPhotoLibrary = PhotoLibrarySaver.defaultValue
    @AppStorage(SoundPlayer.volumeStorageKey) private var soundVolume = SoundPlayer.defaultVolume

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("撮った写真を写真アプリにも保存する", isOn: $savesToPhotoLibrary)
                        .tint(Theme.accent)
                } header: {
                    Text("撮った写真")
                        .font(Theme.font(.footnote))
                } footer: {
                    Text("アプリのカメラで撮った写真を、写真アプリにも保存します。アルバムから取り込んだ写真は保存しません。")
                        .font(Theme.font(.footnote))
                }
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                        // 指を離したときに、選んだ音量でハンコの音を 1 回鳴らす（試し聞き）
                        Slider(value: $soundVolume, in: 0...1) { isEditing in
                            if !isEditing {
                                SoundPlayer.play(.stampPress)
                            }
                        }
                        .tint(Theme.accent)
                        .accessibilityLabel("効果音の音量")
                        .accessibilityValue(Text(verbatim: "\(Int((soundVolume * 100).rounded()))%"))
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                    }
                } header: {
                    Text("効果音の音量")
                        .font(Theme.font(.footnote))
                } footer: {
                    Text("「う、うまい」を付けたときのハンコの音の大きさです。いちばん左にすると鳴りません。マナーモードのときは鳴りません。")
                        .font(Theme.font(.footnote))
                }
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
                    // 上の `.font` が効いて、タイトルの「設定」より大きく見えるので、小さくする
                    .font(Theme.font(.caption))
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
