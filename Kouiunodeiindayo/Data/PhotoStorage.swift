import Foundation
import OSLog
import SwiftUI
import UIKit

/// 写真ファイルの保存・読み込み・サムネイル作成・削除をまとめた層。
/// 置き場所とファイル名の決まりは `docs/data-model.md` の「写真ファイル」が正。
/// SwiftData を知らないので、`Record` ではなく id とファイル名を受け取る。
struct PhotoStorage {
    /// 実機・シミュレータで使うもの。プレビューやテストは一時フォルダのものに差し替える。
    static let standard = PhotoStorage(directory: URL.applicationSupportDirectory.appending(path: "Photos"))

    /// 写真とサムネイルを置くフォルダ。
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// 写真とサムネイルを書き出し、写真のファイル名を返す。
    func savePhotos(_ image: UIImage, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let photoData = Self.jpegData(from: image, maxLength: Self.photoMaxLength)
        // 2000px に縮めた画像からサムネイルを作る（撮影直後の大きな画像を 2 度デコードしないため）
        guard let resized = UIImage(data: photoData) else {
            throw PhotoStorageError.photoRenderingFailed
        }
        let thumbnailData = Self.jpegData(from: resized, maxLength: Self.thumbnailMaxLength)

        let photoFileName = Self.photoFileName(for: id)
        let photoURL = directory.appending(path: photoFileName)
        // 書き込み中に落ちても中途半端な JPEG が残らないよう、atomic で書く
        try photoData.write(to: photoURL, options: .atomic)
        do {
            try thumbnailData.write(to: directory.appending(path: Self.thumbnailFileName(for: id)), options: .atomic)
        } catch {
            // 写真だけ残ると誰も片付けない（呼び出し側は id を知らない）ので、ここで消す
            do {
                try FileManager.default.removeItem(at: photoURL)
            } catch let removeError {
                Self.logger.error(
                    "サムネイルの書き込みに失敗したあと、写真を消せなかった: \(photoFileName, privacy: .public) \(removeError.localizedDescription, privacy: .public)"
                )
            }
            throw error
        }
        return photoFileName
    }

    /// 写真本体を読む。ホームの今日の一枚・仕分けのカード・記録の詳細で使う。
    func photo(fileName: String) -> UIImage? {
        let url = photoURL(fileName: fileName)
        guard let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else {
            // 記録を消した直後の再描画などでも通るので、error にはしない
            Self.logger.notice("写真を読めなかった: \(fileName, privacy: .public)")
            return nil
        }
        return image
    }

    /// 写真ファイルの場所。画像を読まずにファイルのまま渡したいとき（Vision に渡すなど）に使う。
    func photoURL(fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    /// 一覧のグリッドなど、小さく並べる場所で使う。
    func thumbnail(id: UUID) -> UIImage? {
        photo(fileName: Self.thumbnailFileName(for: id))
    }

    /// 写真とサムネイルを消す。もともと無いファイルは成功扱いにする。
    func deletePhotos(id: UUID, fileName: String) throws {
        try removeIfExists(at: directory.appending(path: fileName))
        try removeIfExists(at: directory.appending(path: Self.thumbnailFileName(for: id)))
    }

    private func removeIfExists(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - ファイル名と書き出しの詳細

extension PhotoStorage {
    private static let logger = Logger(category: "PhotoStorage")

    /// 写真の長辺の目安（px）。
    private static let photoMaxLength: CGFloat = 2000
    /// サムネイルの長辺の目安（px）。
    private static let thumbnailMaxLength: CGFloat = 400
    private static let jpegQuality: CGFloat = 0.8

    private static func photoFileName(for id: UUID) -> String {
        "\(id.uuidString).jpg"
    }

    private static func thumbnailFileName(for id: UUID) -> String {
        "\(id.uuidString)_thumb.jpg"
    }

    /// 縮小と JPEG 化を 1 回の描画でまとめて行う。
    private static func jpegData(from image: UIImage, maxLength: CGFloat) -> Data {
        let size = fittedSize(of: image.size, maxLength: maxLength)
        let format = UIGraphicsImageRendererFormat.default()
        // 既定は画面の倍率なので、実機では指定の 2〜3 倍の大きさになってしまう
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
            .jpegData(withCompressionQuality: jpegQuality) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
    }

    /// 長辺が `maxLength` に収まる大きさ。元より大きくはしない。
    private static func fittedSize(of size: CGSize, maxLength: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxLength else { return size }
        let ratio = maxLength / longest
        return CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
    }
}

enum PhotoStorageError: Error {
    /// 縮小した JPEG を読み直せず、サムネイルを作れなかった。
    case photoRenderingFailed
}

extension EnvironmentValues {
    @Entry var photoStorage = PhotoStorage.standard
}
