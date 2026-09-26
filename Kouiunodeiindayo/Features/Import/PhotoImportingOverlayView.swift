import SwiftUI

/// 取り込みの進み具合（済んだ枚数・全体）。取り込み中だけ値がある
struct PhotoImportProgress: Equatable {
    var done: Int
    var total: Int
}

/// 取り込み中の幕。回るマークと「取り込み中 n / m」。
/// `RootView` がページャーと下タブの上にまとめて重ねる（下は触れない。色の付いた幕が触れた指を受け取る。
/// ページャーの横スワイプは `scrollDisabled` では止まらなかったので、幕で受け止める）
struct PhotoImportingOverlayView: View {
    let progress: PhotoImportProgress

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(verbatim: "取り込み中 \(progress.done) / \(progress.total)")
                .font(Theme.font(.headline, bold: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.opacity(0.85))
        .accessibilityElement(children: .combine)
    }
}

#Preview("取り込み中") {
    PhotoImportingOverlayView(progress: PhotoImportProgress(done: 3, total: 12))
}
