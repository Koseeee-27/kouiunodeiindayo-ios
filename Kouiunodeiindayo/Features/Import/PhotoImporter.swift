import Foundation
import ImageIO
import OSLog
import PhotosUI
import SwiftUI
import UIKit

/// 取り込みの結果。仕分けの上の 1 行と、0 枚のときのアラートに使う。
/// `fullScreenCover(item:)` で仕分けを出すので `Identifiable` にする（取り込むたびに別の値）。
struct PhotoImportResult: Identifiable {
    let id = UUID()
    /// 仕分け待ちに入れた記録の id（取り込んだ写真だけを仕分けるため）
    var importedIDs: [UUID] = []
    /// 食事でないとして入れなかった枚数
    var excludedCount = 0
    /// データを受け取れなかった・画像として読めなかった・保存できなかった枚数。除外には数えない
    var failedCount = 0
}

/// 1 枚ぶんの、裏で作ったもの。
nonisolated struct PreparedPhoto: Sendable {
    /// 長辺 `PhotoImporter.maxPixelSize` に縮め、向きを直したもの
    let image: CGImage
    /// EXIF の撮影日時。入っていなければ nil（呼ぶ側で取り込んだ時刻にする）
    let takenAt: Date?
}

/// アルバムからの取り込み（機能18）。画面を持たない。
/// 写真は `PhotosPicker` が選んだものだけを受け取るので、写真ライブラリの許可は要らない。撮影日時は画像データの EXIF から読む。
enum PhotoImporter {
    static let maxSelectionCount = 30
    /// 縮める長辺（px）。`PhotoStorage` が保存する大きさと同じ
    nonisolated static let maxPixelSize = 2000

    /// 画像データから、縮めた画像と撮影日時を作る。メインスレッドの外で動く。読めなければ nil。
    /// 48MP の写真をそのまま描くと 1 枚 190MB 前後になるので、`CGImageSource` で読みながら縮める。向きもここで直す。
    @concurrent
    nonisolated static func prepare(_ data: Data) async -> PreparedPhoto? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        return PreparedPhoto(image: image, takenAt: takenAt(fromImageProperties: properties))
    }

    /// EXIF の撮影日時（`DateTimeOriginal`）を `Date` にする。時差（`OffsetTimeOriginal`）があればそれで、無ければ `timeZone` で読む。
    /// 入っていない・形が崩れているときは nil。テストのために分けて出す。
    nonisolated static func takenAt(fromImageProperties properties: [CFString: Any], timeZone: TimeZone = .current)
        -> Date?
    {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: original + offset) {
                return date
            }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.date(from: original)
    }
}

/// 選ばれた項目を 1 枚ずつ取り込む（同時に何枚も縮めない。メモリを抑えるため）。
/// テストのために、データの受け取り・準備・判定・保存をクロージャで差し替えられるようにする。本物は `live(store:)`。
struct PhotoImportRunner<Item> {
    private static var logger: Logger { Logger(category: "PhotoImport") }

    /// 本物は `item.loadTransferable(type: Data.self)`。nil か throw なら読めなかったに数える
    var loadData: (Item) async throws -> Data?
    /// 本物は `PhotoImporter.prepare`
    var prepare: (Data) async -> PreparedPhoto?
    /// 本物は `ImageLabeler.labels(of:)`。throw したら食事扱いで取り込む（選んだ写真を黙って捨てない）
    var labels: (CGImage) async throws -> [ImageLabel]
    /// 本物は `RecordStore.add(image:takenAt:)` の id
    var save: (UIImage, Date) throws -> UUID

    /// 進み具合は `onProgress(済んだ枚数, 全体)` で 1 枚ごとに知らせる。撮影日時が無い写真は `now()` で保存する
    func run(_ items: [Item], now: () -> Date = { .now }, onProgress: (Int, Int) -> Void) async -> PhotoImportResult {
        var result = PhotoImportResult()
        let start = ContinuousClock.now
        for (index, item) in items.enumerated() {
            defer { onProgress(index + 1, items.count) }
            let data: Data?
            do {
                data = try await loadData(item)
            } catch {
                // ファイルの場所などは出さず、種類だけ残す
                Self.logger.error("取り込み: データを受け取れなかった: \(String(describing: type(of: error)), privacy: .public)")
                data = nil
            }
            guard let data else {
                result.failedCount += 1
                continue
            }
            guard let prepared = await prepare(data) else {
                Self.logger.error("取り込み: 画像として読めなかった")
                result.failedCount += 1
                continue
            }
            do {
                // ファイルに書く前に判定するので、除外した写真はファイルを作らない
                if !FoodPhotoFilter.isFood(try await labels(prepared.image)) {
                    result.excludedCount += 1
                    continue
                }
            } catch {
                Self.logger.error("取り込み: 食事らしいかを判定できなかったので取り込む: \(error.localizedDescription, privacy: .public)")
            }
            do {
                let id = try save(UIImage(cgImage: prepared.image), prepared.takenAt ?? now())
                result.importedIDs.append(id)
            } catch {
                Self.logger.error("取り込み: 保存できなかった: \(error.localizedDescription, privacy: .public)")
                result.failedCount += 1
            }
        }
        let elapsed = (ContinuousClock.now - start).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        Self.logger.info(
            "取り込み: \(items.count) 枚 \(seconds, format: .fixed(precision: 1)) 秒（取り込み \(result.importedIDs.count)・除外 \(result.excludedCount)・読めなかった \(result.failedCount)）"
        )
        return result
    }
}

extension PhotoImportRunner where Item == PhotosPickerItem {
    /// ホームの入口から使う本物。
    static func live(store: RecordStore) -> Self {
        PhotoImportRunner(
            loadData: { item in try await item.loadTransferable(type: Data.self) },
            prepare: { data in await PhotoImporter.prepare(data) },
            labels: { image in try await ImageLabeler.labels(of: image) },
            save: { image, takenAt in try store.add(image: image, takenAt: takenAt).id }
        )
    }
}
