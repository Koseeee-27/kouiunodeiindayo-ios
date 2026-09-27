import OSLog
import Photos
import UIKit

/// 撮った写真を、写真アプリ（カメラロール）にも保存する（機能19）。画面は持たない。
/// 許可は「追加だけ」（`addOnly`）。写真アプリの中身は読まない。専用のアルバムも作らない（作るには広い許可が要るため）。
/// 保存するかの設定値のキーは `docs/data-model.md` の「設定値」が正。
enum PhotoLibrarySaver {
    /// `@AppStorage` で使うキー。文字列をここ1か所だけに置く
    static let storageKey = "savesToPhotoLibrary"
    /// 初期設定はオン
    static let defaultValue = true

    /// 写真がどこから来たか。アルバムから選んだ写真は、もう写真アプリにあるので保存しない
    enum Source {
        case camera
        case photoLibrary
    }

    /// 写真アプリにも保存するか
    static func shouldSave(source: Source, isEnabled: Bool) -> Bool {
        source == .camera && isEnabled
    }

    private static var logger: Logger { Logger(category: "PhotoLibrarySaver") }

    /// 許可を聞いてから（初めてのときだけ iOS の確認が出る）、写真アプリに追加する。
    /// 断られた・失敗したときは、ログに残して何もしない（アプリへの記録と、撮る流れは止めない）
    static func save(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            logger.notice("写真アプリへの保存を飛ばした: 許可が無い（\(String(describing: status.rawValue), privacy: .public)）")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            logger.error("写真アプリに保存できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }
}
