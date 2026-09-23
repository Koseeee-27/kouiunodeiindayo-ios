import OSLog
import SwiftUI
import UIKit

/// iPhone 標準のカメラ（`UIImagePickerController`）を包んだもの。撮り直しは標準の確認画面で行う。
/// シミュレータと、カメラが使えない実機（スクリーンタイムの制限など）では写真ライブラリになる（`sourceType`）。
/// 中身を自作カメラに差し替えるときも口（`onPick` / `onCancel`）は変えない（#32）。
/// 閉じるのは呼び出し側（`CameraFlowView` が中身を切り替える）。ここで `dismiss` は呼ばない。
struct CameraView: UIViewControllerRepresentable {
    /// 撮った（選んだ）写真を渡す。
    let onPick: (UIImage) -> Void
    /// キャンセルされた、または写真が取れなかったとき。
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = Self.sourceType
        picker.delegate = context.coordinator
        return picker
    }

    private static var sourceType: UIImagePickerController.SourceType {
        #if targetEnvironment(simulator)
            // iOS 27 のシミュレータは `.camera` を使えると答え、標準カメラの画面も出るが、映像が来ずシャッターが効かない
            // iOS 27 SDK では `.photoLibrary` が将来の非推奨予告（`API_TO_BE_DEPRECATED`、PHPicker へ）。警告が出たら `PHPickerViewController` に替える
            return .photoLibrary
        #else
            return UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        #endif
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Coordinator は作り直されないので、親の再描画で渡された新しいクロージャに付け直す
        context.coordinator.onPick = onPick
        context.coordinator.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private static let logger = Logger(category: "CameraView")

        var onPick: (UIImage) -> Void
        var onCancel: () -> Void

        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                // 通常は取れる。取れなくても落とさず、キャンセル扱いにする
                Self.logger.error("撮った写真を取り出せなかった")
                onCancel()
                return
            }
            onPick(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// プレビューはシミュレータ上なので写真ライブラリが出る
#Preview {
    CameraView(onPick: { _ in }, onCancel: {})
}
