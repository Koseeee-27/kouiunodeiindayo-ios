import Foundation
import SwiftData
import UIKit

/// プレビュー用のサンプルデータ。表示の確認だけに使うので、失敗したら気づけるよう落とす。
enum SampleData {
    /// 本物の写真フォルダを汚さないよう、一時フォルダに書く。
    static let photoStorage = PhotoStorage(directory: URL.temporaryDirectory.appending(path: "SamplePhotos"))

    /// 記録が 0 件のコンテナ。
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Record.self, configurations: configuration)
    }

    /// サンプルを 5 件入れたコンテナ。ジャンルと「うまい」を一通り含む。
    static func makePreviewContainer() -> ModelContainer {
        let container = makeContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: photoStorage)

        let samples: [(color: UIColor, genre: Genre, isFavorite: Bool, daysAgo: Int)] = [
            (.systemOrange, .unsorted, false, 0),
            (.systemRed, .food, true, 0),
            (.systemTeal, .drink, false, 1),
            (.systemPink, .dessert, true, 2),
            (.systemGray, .noGenre, false, 3)
        ]
        for sample in samples {
            let takenAt = Date.now.addingTimeInterval(-oneDay * Double(sample.daysAgo))
            // プレビュー用なので、作れなければ落として気づく
            let record = try! store.add(image: makeImage(color: sample.color), takenAt: takenAt)
            store.setGenre(sample.genre, for: record)
            if sample.isFavorite {
                store.toggleFavorite(record)
            }
        }
        return container
    }

    /// 写真の代わりに使う単色の画像。デバッグ用の追加ボタンからも使う。
    static func makeImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static let oneDay: TimeInterval = 60 * 60 * 24
}
