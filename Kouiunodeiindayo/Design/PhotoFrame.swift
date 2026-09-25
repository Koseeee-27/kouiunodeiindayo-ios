import SwiftUI

/// 写真のコマ枠の太さ。マンガのコマに見せるため、墨の線で囲み、角丸は付けない。
/// `main`：主役の写真（ホームの今日の一枚・仕分けのカード・記録の詳細）
/// `small`：小さく並べる写真（ホームの最近の写真・一覧）
enum PhotoFrame {
    case main
    case small

    fileprivate var lineWidth: CGFloat {
        switch self {
        case .main: Theme.photoFrameWidthMain
        case .small: Theme.photoFrameWidthSmall
        }
    }
}

extension View {
    /// 四角く切り抜き、内側に墨の枠を引く。外寸は変えない（写真の端が線の太さ分だけ隠れる）
    func photoFrame(_ frame: PhotoFrame) -> some View {
        clipped()
            .overlay {
                Rectangle()
                    .strokeBorder(Theme.line, lineWidth: frame.lineWidth)
                    // 枠は飾りなので、押す判定と読み上げから外す
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
