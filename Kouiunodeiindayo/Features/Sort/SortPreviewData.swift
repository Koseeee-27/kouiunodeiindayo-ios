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
}
