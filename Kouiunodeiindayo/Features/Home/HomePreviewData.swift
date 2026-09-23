import Foundation
import SwiftData
import UIKit

/// ホームのプレビュー専用のサンプルデータ。共有の `SampleData` を土台に、ホームで見たい状態を足す。
enum HomePreviewData {
    /// サンプルデータの仕分け待ちを「食べ物」にしたもの（仕分け待ち0枚。今日の記録が2件）。
    static func makeNoUnsortedContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let unsorted = Genre.unsorted.rawValue
        let descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.genre == unsorted })
        // プレビュー用なので、作れなければ落として気づく
        for record in try! container.mainContext.fetch(descriptor) {
            store.setGenre(.food, for: record)
        }
        return container
    }

    /// 昨日〜4日前の記録だけを4件入れたもの（仕分け待ち無し・今日の記録無し）。
    static func makeNoTodayContainer() -> ModelContainer {
        let container = SampleData.makeContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let samples: [(color: UIColor, genre: Genre, isFavorite: Bool, daysAgo: Int)] = [
            (.systemGreen, .food, true, 1),
            (.systemPurple, .drink, false, 2),
            (.systemIndigo, .dessert, false, 3),
            (.systemBrown, .noGenre, false, 4),
        ]
        for sample in samples {
            let record = try! store.add(
                image: SampleData.makeImage(color: sample.color),
                takenAt: Date.now.addingTimeInterval(-oneDay * Double(sample.daysAgo))
            )
            store.setGenre(sample.genre, for: record)
            if sample.isFavorite {
                store.toggleFavorite(record)
            }
        }
        return container
    }

    /// サンプルデータに、4〜9日前の「食べ物」を6件足したもの（仕分け済みが計10件）。
    static func makeManyContainer() -> ModelContainer {
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let colors: [UIColor] = [.systemGreen, .systemPurple, .systemIndigo, .systemBrown, .systemYellow, .systemCyan]
        for (index, color) in colors.enumerated() {
            let record = try! store.add(
                image: SampleData.makeImage(color: color),
                takenAt: Date.now.addingTimeInterval(-oneDay * Double(index + 4))
            )
            store.setGenre(.food, for: record)
        }
        return container
    }

    private static let oneDay: TimeInterval = 60 * 60 * 24
}
