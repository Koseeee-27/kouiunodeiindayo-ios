import Foundation
import SwiftData
import UIKit

/// 仕分けのプレビュー専用のサンプルデータ。共有の `SampleData` を土台に、仕分けで見たい状態を足す。
enum SortPreviewData {
    /// サンプルデータに仕分け待ちを2件足したもの（仕分け待ちは計3件）。
    static func makeManyUnsortedContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        for (index, color) in [UIColor.systemGreen, .systemPurple].enumerated() {
            let takenAt = Date.now.addingTimeInterval(-60 * 60 * Double(index + 1))
            // プレビュー用なので、作れなければ落として気づく
            _ = try! store.add(image: SampleData.makeImage(color: color), takenAt: takenAt)
        }
        return container
    }

    /// 提案をまだ問い合わせていない仕分け待ちだけ（3件）。共有の `SampleData` には提案済みの仕分け待ちがあるので、使わずに作る。
    /// 提案なし・通信できない・後から届くのプレビューで使う
    static func makeUnsuggestedContainer() -> ModelContainer {
        let container = SampleData.makeContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        for (index, color) in [UIColor.systemOrange, .systemGreen, .systemPurple].enumerated() {
            let takenAt = Date.now.addingTimeInterval(-60 * 60 * Double(index))
            // プレビュー用なので、作れなければ落として気づく
            _ = try! store.add(image: SampleData.makeImage(color: color), takenAt: takenAt)
        }
        return container
    }

    /// 仕分け待ちのうち一番新しい1件の id（撮った直後の仕分けのプレビューで、今撮った1枚に見立てる）。
    static func newestUnsortedID(in container: ModelContainer) -> UUID {
        let unsorted = Genre.unsorted.rawValue
        var descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.genre == unsorted },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        // プレビュー用なので、無ければ落として気づく
        return try! container.mainContext.fetch(descriptor).first!.id
    }

    /// 仕分け待ちの id を新しい順に（取り込みから開いた仕分けのプレビューで、取り込んだ写真に見立てる）。
    static func unsortedIDs(in container: ModelContainer) -> [UUID] {
        let unsorted = Genre.unsorted.rawValue
        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.genre == unsorted },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        // プレビュー用なので、取れなければ落として気づく
        return try! container.mainContext.fetch(descriptor).map(\.id)
    }

    /// サンプルデータの仕分け待ちに「うまい」を付けたもの。
    static func makeFavoriteContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let unsorted = Genre.unsorted.rawValue
        let descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.genre == unsorted })
        // プレビュー用なので、無ければ落として気づく
        let record = try! container.mainContext.fetch(descriptor).first!
        store.toggleFavorite(record)
        return container
    }

    /// サンプルデータの先頭に、横長の写真の仕分け待ちを1件足したもの。
    /// 真ん中に丸と格子を描いておき、縦横比が崩れると丸がつぶれて分かるようにする。
    static func makeLandscapeContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        // 一番新しくして先頭に出す。プレビュー用なので、作れなければ落として気づく
        _ = try! store.add(image: makeLandscapeImage(), takenAt: .now.addingTimeInterval(60))
        return container
    }

    private static func makeLandscapeImage() -> UIImage {
        let size = CGSize(width: 1600, height: 1200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBrown.setFill()
            for x in stride(from: 0, to: size.width, by: 200) {
                context.fill(CGRect(x: x, y: 0, width: 20, height: size.height))
            }
            for y in stride(from: 0, to: size.height, by: 200) {
                context.fill(CGRect(x: 0, y: y, width: size.width, height: 20))
            }
            UIColor.systemRed.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 500, y: 300, width: 600, height: 600))
        }
    }
}
