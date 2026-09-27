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

    /// 追加だけの許可を聞く（初めてのときだけ iOS の確認が出る）。許可されていれば true
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            logger.notice("写真アプリへの追加の許可が無い（\(String(describing: status.rawValue), privacy: .public)）")
            return false
        }
        return true
    }

    /// 撮った写真を保存する（自動保存）。断られた・失敗したときは、ログに残して何もしない（アプリへの記録と、撮る流れは止めない）
    static func save(_ image: UIImage) async {
        guard await requestAccess() else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            logger.error("写真アプリに保存できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: 選んで保存する（一覧の選ぶモード・記録の詳細）

    /// 選んで保存したときの結果
    enum Outcome: Equatable {
        /// 許可を断られた
        case denied
        case finished(saved: Int, failed: Int)
    }

    /// 写真ファイルを 1 枚ずつ写真アプリに追加する。設定のスイッチ（撮った写真の自動保存）とは関係なく保存する。
    /// アルバムから取り込んだ写真も保存する（写真アプリで重複してもよい）
    static func save(fileURLs: [URL]) async -> Outcome {
        guard await requestAccess() else { return .denied }
        var saved = 0
        var failed = 0
        for url in fileURLs {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
                saved += 1
            } catch {
                logger.error("写真アプリに保存できなかった: \(error.localizedDescription, privacy: .public)")
                failed += 1
            }
        }
        return .finished(saved: saved, failed: failed)
    }

    /// 結果の知らせ（アラートの題）
    static func message(for outcome: Outcome) -> String {
        switch outcome {
        case .denied:
            "設定から写真への追加を許可してください"
        case .finished(let saved, 0):
            "\(saved) 枚を保存しました"
        case .finished(0, _):
            "保存できませんでした"
        case .finished(let saved, let failed):
            "\(saved) 枚を保存しました（\(failed) 枚は保存できませんでした）"
        }
    }
}
