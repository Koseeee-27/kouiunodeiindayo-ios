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
        // `makeContainer()` から始めると一時フォルダの掃除が走らず、あとから開いた別のプレビューの掃除で
        // ここで書いた写真が消えることがある。掃除込みの `makePreviewContainer()` を空にしてから足す
        let container = SampleData.makePreviewContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        // プレビュー用なので、消せなければ落として気づく
        try! store.deleteAll()
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

    /// 記録の詳細のプレビュー用。「食べ物」の記録 1 件に `tags` を付けたもの（ほかの記録は入れない）。
    /// `photoSize` を渡すと、その形の写真にする（横長・正方形の見え方を見るため。形が分かるよう、格子と丸を描く）
    static func makeTaggedContainer(tags: [Tag], photoSize: CGSize? = nil) -> ModelContainer {
        let container = SampleData.makeContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: SampleData.photoStorage)
        let image = photoSize.map(makeShapedImage) ?? SampleData.makeImage(color: .systemOrange)
        // プレビュー用なので、作れなければ落として気づく
        let record = try! store.add(image: image, takenAt: .now)
        store.setGenre(.food, for: record)
        store.setTags(tags, for: record)
        return container
    }

    /// 形の分かる写真の代わり。橙の地に格子と、真ん中の丸（縦横比が崩れると丸がつぶれる）
    private static func makeShapedImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBrown.setFill()
            for x in stride(from: 0, to: size.width, by: 200) {
                context.fill(CGRect(x: x, y: 0, width: 12, height: size.height))
            }
            for y in stride(from: 0, to: size.height, by: 200) {
                context.fill(CGRect(x: 0, y: y, width: size.width, height: 12))
            }
            let side = min(size.width, size.height) * 0.6
            UIColor.white.setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side))
        }
    }

    private static let oneDay: TimeInterval = 60 * 60 * 24
}
