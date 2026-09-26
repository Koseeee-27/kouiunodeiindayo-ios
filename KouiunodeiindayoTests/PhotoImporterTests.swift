import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import Kouiunodeiindayo

@MainActor
struct PhotoImporterTests {
    // MARK: 撮影日時

    @Test func 時差が無ければ渡した時間帯で読む() throws {
        let properties = Self.exif(["DateTimeOriginal": "2026:09:26 12:34:56"])
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let date = PhotoImporter.takenAt(fromImageProperties: properties, timeZone: tokyo)
        // 2026-09-26 03:34:56 UTC
        #expect(date == Date(timeIntervalSince1970: 1_790_393_696))
    }

    @Test func 時差があればそれで読む() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let plus9 = PhotoImporter.takenAt(
            fromImageProperties: Self.exif(["DateTimeOriginal": "2026:09:26 12:34:56", "OffsetTimeOriginal": "+09:00"]),
            timeZone: utc)
        let minus5 = PhotoImporter.takenAt(
            fromImageProperties: Self.exif(["DateTimeOriginal": "2026:09:26 12:34:56", "OffsetTimeOriginal": "-05:00"]),
            timeZone: utc)
        #expect(plus9 == Date(timeIntervalSince1970: 1_790_393_696))
        #expect(minus5 == Date(timeIntervalSince1970: 1_790_393_696 + 14 * 60 * 60))
    }

    @Test func 撮影日時が無い・形が崩れているとnil() {
        #expect(PhotoImporter.takenAt(fromImageProperties: [:]) == nil)
        #expect(PhotoImporter.takenAt(fromImageProperties: Self.exif(["ExposureTime": 0.01])) == nil)
        #expect(PhotoImporter.takenAt(fromImageProperties: Self.exif(["DateTimeOriginal": "2026-09-26 12:00"])) == nil)
    }

    // MARK: 縮める

    @Test func 長辺を縮めて撮影日時も読む() async throws {
        let data = try Self.makeJPEG(
            width: 4000, height: 3000, dateTimeOriginal: "2026:09:20 12:30:00", offset: "+09:00")
        let prepared = try #require(await PhotoImporter.prepare(data))
        #expect(prepared.image.width == 2000)
        #expect(prepared.image.height == 1500)
        #expect(prepared.takenAt == Date(timeIntervalSince1970: 1_789_875_000))
    }

    @Test func 向きを直して縦長になる() async throws {
        // 右 90° に回して見せる横長の画像（縦向きで撮った iPhone の写真と同じ形）
        let data = try Self.makeJPEG(width: 4000, height: 3000, orientation: 6)
        let prepared = try #require(await PhotoImporter.prepare(data))
        #expect(prepared.image.width < prepared.image.height)
        #expect(prepared.image.height == 2000)
        #expect(prepared.takenAt == nil)
    }

    @Test func 壊れたデータはnil() async {
        #expect(await PhotoImporter.prepare(Data("not an image".utf8)) == nil)
    }

    // MARK: 取り込みの流れ

    @Test func 受け取れなかった写真は読めなかったに数えてほかは取り込む() async {
        let saved = SavedPhotos()
        let runner = Self.makeRunner(
            saved: saved,
            loadData: { index in
                if index == 1 { throw CocoaError(.fileReadUnknown) }
                return Data([UInt8(index)])
            })
        let result = await runner.run([0, 1, 2], onProgress: { _, _ in })
        #expect(result.importedIDs.count == 2)
        #expect(result.importedIDs == saved.ids)
        #expect(result.failedCount == 1)
        #expect(result.excludedCount == 0)
    }

    @Test func 撮影日時の無い写真は今の時刻で保存する() async {
        let saved = SavedPhotos()
        let taken = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        var runner = Self.makeRunner(saved: saved)
        runner.prepare = { data in
            PreparedPhoto(image: Self.smallImage, takenAt: data.first == 0 ? taken : nil)
        }
        _ = await runner.run([0, 1], now: { now }, onProgress: { _, _ in })
        #expect(saved.dates == [taken, now])
    }

    @Test func 進み具合を1枚ごとに知らせる() async {
        let saved = SavedPhotos()
        var runner = Self.makeRunner(saved: saved)
        // 読めなかった写真でも進み具合は進む
        runner.prepare = { data in data.first == 1 ? nil : PreparedPhoto(image: Self.smallImage, takenAt: nil) }
        var progress: [String] = []
        _ = await runner.run([0, 1, 2], onProgress: { done, total in progress.append("\(done)/\(total)") })
        #expect(progress == ["1/3", "2/3", "3/3"])
    }

    @Test func 保存できなかった写真は読めなかったに数える() async {
        var runner = Self.makeRunner(saved: SavedPhotos())
        runner.save = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let result = await runner.run([0], onProgress: { _, _ in })
        #expect(result.importedIDs.isEmpty)
        #expect(result.failedCount == 1)
    }

    // MARK: 道具

    /// 保存された写真の撮影日時と id を控える。
    final class SavedPhotos {
        var ids: [UUID] = []
        var dates: [Date] = []
    }

    static let smallImage: CGImage = {
        // テスト用なので、作れなければ落として気づく
        let context = CGContext(
            data: nil, width: 4, height: 3, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return context.makeImage()!
    }()

    static func makeRunner(
        saved: SavedPhotos,
        loadData: @escaping (Int) async throws -> Data? = { Data([UInt8($0)]) }
    ) -> PhotoImportRunner<Int> {
        PhotoImportRunner(
            loadData: loadData,
            prepare: { _ in PreparedPhoto(image: smallImage, takenAt: nil) },
            save: { _, date in
                let id = UUID()
                saved.ids.append(id)
                saved.dates.append(date)
                return id
            }
        )
    }

    static func exif(_ values: [String: Any]) -> [CFString: Any] {
        [kCGImagePropertyExifDictionary: values as CFDictionary]
    }

    /// EXIF の撮影日時と向きを入れた JPEG を作る。
    static func makeJPEG(
        width: Int, height: Int, dateTimeOriginal: String? = nil, offset: String? = nil, orientation: Int = 1
    )
        throws -> Data
    {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(UIColor.systemOrange.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        var exif: [CFString: Any] = [:]
        if let dateTimeOriginal { exif[kCGImagePropertyExifDateTimeOriginal] = dateTimeOriginal }
        if let offset { exif[kCGImagePropertyExifOffsetTimeOriginal] = offset }
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyOrientation: orientation,
        ]
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
