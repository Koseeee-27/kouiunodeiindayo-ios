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

extension PhotoImportResult {
    /// 仕分けの上の 1 行。「取り込み n 枚 ／ 除外 m 枚」。読めなかった写真があるときだけ「／ 読めなかった k 枚」を足す
    var summaryText: String {
        countTexts(includesImported: true).joined(separator: " ／ ")
    }

    /// `summaryText` の読み上げ。「／」を読ませず、読点でつなぐ
    var summaryAccessibilityLabel: String {
        countTexts(includesImported: true).joined(separator: "、")
    }

    /// 1 枚も取り込めなかったときのアラートの題。全部読めなかった（除外が 0）ときだけ分ける
    var emptyAlertTitle: String {
        excludedCount == 0 && failedCount > 0 ? "写真を読み込めませんでした" : "食事の写真が見つかりませんでした"
    }

    /// 1 枚も取り込めなかったときのアラートの本文。「除外 m 枚」（読めなかった写真があるときだけ、その枚数も足す）
    var emptyAlertMessage: String {
        countTexts(includesImported: false).joined(separator: " ／ ")
    }

    /// `emptyAlertMessage` の読み上げ
    var emptyAlertAccessibilityLabel: String {
        countTexts(includesImported: false).joined(separator: "、")
    }

    private func countTexts(includesImported: Bool) -> [String] {
        var texts: [String] = []
        if includesImported {
            texts.append("取り込み \(importedIDs.count) 枚")
        }
        texts.append("除外 \(excludedCount) 枚")
        if failedCount > 0 {
            texts.append("読めなかった \(failedCount) 枚")
        }
        return texts
    }
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

    /// 選ばれた写真で取り込みを始めてよいか。取り込み中は二重に始めない（読み上げなどから、幕の下の入口が押されたときのため）
    static func shouldStart(selectedCount: Int, isImporting: Bool) -> Bool {
        selectedCount > 0 && !isImporting
    }
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

    /// EXIF の撮影日時（`DateTimeOriginal`）を `Date` にする。時差（`OffsetTimeOriginal`、無ければ `OffsetTime`）があればそれで、
    /// 無い・形が崩れているときは `timeZone` で読む。
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
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
        for key in [kCGImagePropertyExifOffsetTimeOriginal, kCGImagePropertyExifOffsetTime] {
            if let offset = exif[key] as? String, let date = formatter.date(from: original + offset) {
                return date
            }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.date(from: original)
    }
}

/// 選ばれた項目を 1 枚ずつ取り込む（同時に何枚も縮めない。メモリを抑えるため）。データの受け取りだけは先に始めておく（`prefetchCount`）。
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

    /// データの受け取りを、今の 1 枚より何枚先まで先に始めるか（同時に動く受け取りは最大 `prefetchCount + 1` 本）。
    /// 受け取り（iCloud からのダウンロードを含む）は待ちが長く、縮小・判定・保存と重ねられるため（#120）。
    /// 縮小・判定・保存は今までどおり 1 枚ずつ、選んだ順に行う。汎用の型なので `static let` は置けない
    static var prefetchCount: Int { 2 }

    /// 進み具合は `onProgress(済んだ枚数, 全体)` で 1 枚ごとに知らせる。撮影日時が無い写真は `now()` で保存する
    func run(_ items: [Item], now: () -> Date = { .now }, onProgress: (Int, Int) -> Void) async -> PhotoImportResult {
        var result = PhotoImportResult()
        let start = ContinuousClock.now
        var timings = StageTimings()
        // 本人が選んだ 1 枚は、食事の判定で除かない（#110）。2 枚以上のときだけ判定する
        let filtersFood = items.count > 1
        // 受け取りのタスク。受け取ったらすぐ nil にしてデータを手放す（持つのは最大 `prefetchCount + 1` 枚）
        var loads: [Task<Data?, Error>?] = Array(repeating: nil, count: items.count)
        func startLoad(_ index: Int) {
            guard index < items.count else { return }
            let item = items[index]
            loads[index] = Task { try await loadData(item) }
        }
        for index in 0..<min(Self.prefetchCount + 1, items.count) {
            startLoad(index)
        }
        for index in items.indices {
            defer { onProgress(index + 1, items.count) }
            let loadStart = ContinuousClock.now
            let data: Data?
            do {
                data = try await loads[index]?.value
            } catch {
                // ファイルの場所などは出さず、種類だけ残す
                Self.logger.error("取り込み: データを受け取れなかった: \(String(describing: type(of: error)), privacy: .public)")
                data = nil
            }
            loads[index] = nil
            startLoad(index + Self.prefetchCount + 1)
            timings.addLoad(ContinuousClock.now - loadStart)
            guard let data else {
                result.failedCount += 1
                continue
            }
            let prepareStart = ContinuousClock.now
            let prepared = await prepare(data)
            timings.prepare += ContinuousClock.now - prepareStart
            guard let prepared else {
                Self.logger.error("取り込み: 画像として読めなかった")
                result.failedCount += 1
                continue
            }
            let labelStart = ContinuousClock.now
            do {
                // ファイルに書く前に判定するので、除外した写真はファイルを作らない
                if filtersFood, !FoodPhotoFilter.isFood(try await labels(prepared.image)) {
                    timings.label += ContinuousClock.now - labelStart
                    result.excludedCount += 1
                    continue
                }
            } catch {
                Self.logger.error("取り込み: 食事らしいかを判定できなかったので取り込む: \(error.localizedDescription, privacy: .public)")
            }
            timings.label += ContinuousClock.now - labelStart
            // 保存（JPEG の書き出し）はメインで重いので、先に幕の描き直しに譲る
            await Task.yield()
            let saveStart = ContinuousClock.now
            do {
                let id = try save(UIImage(cgImage: prepared.image), prepared.takenAt ?? now())
                result.importedIDs.append(id)
            } catch {
                Self.logger.error("取り込み: 保存できなかった: \(error.localizedDescription, privacy: .public)")
                result.failedCount += 1
            }
            timings.save += ContinuousClock.now - saveStart
        }
        // 写真の場所・ラベル・中身は出さない。秒数と枚数だけ
        Self.logger.info(
            "取り込み: \(items.count) 枚 \(StageTimings.seconds(ContinuousClock.now - start), privacy: .public) 秒（取り込み \(result.importedIDs.count)・除外 \(result.excludedCount)・読めなかった \(result.failedCount)）\(timings.summary, privacy: .public)"
        )
        return result
    }
}

/// 取り込みの段ごとの時間の合計（ログ用。#120）。受け取りは、先読みで待たずに済んだぶんは短くなる
private struct StageTimings {
    var load: Duration = .zero
    /// 受け取りを一番長く待った 1 枚（iCloud にしか無い写真の見当に使う）
    var longestLoad: Duration = .zero
    var prepare: Duration = .zero
    var label: Duration = .zero
    var save: Duration = .zero

    mutating func addLoad(_ duration: Duration) {
        load += duration
        longestLoad = max(longestLoad, duration)
    }

    var summary: String {
        "受け取り 合計 \(Self.seconds(load)) 秒（最大 \(Self.seconds(longestLoad)) 秒）・縮小 \(Self.seconds(prepare)) 秒・判定 \(Self.seconds(label)) 秒・保存 \(Self.seconds(save)) 秒"
    }

    static func seconds(_ duration: Duration) -> String {
        let components = duration.components
        return String(format: "%.2f", Double(components.seconds) + Double(components.attoseconds) / 1e18)
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
