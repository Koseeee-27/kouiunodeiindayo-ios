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

    /// サンプルを 5 件入れたコンテナ。ジャンル・「うまい」・タグ・提案を一通り含む。
    /// 仕分け待ちの1件には提案（食べ物・ラーメン・麺類・中華）が届いている。
    static func makePreviewContainer() -> ModelContainer {
        _ = cleanedPhotoDirectory
        let container = makeContainer()
        let store = RecordStore(modelContext: container.mainContext, photoStorage: photoStorage)

        let samples: [(color: UIColor, genre: Genre, isFavorite: Bool, tags: [Tag], daysAgo: Int)] = [
            (.systemOrange, .unsorted, false, [], 0),
            (.systemRed, .food, true, [.ramen, .noodles, .chinese], 0),
            (.systemTeal, .drink, false, [.coffee], 1),
            (.systemPink, .dessert, true, [.cake], 2),
            (.systemGray, .noGenre, false, [], 3),
        ]
        for sample in samples {
            let takenAt = Date.now.addingTimeInterval(-oneDay * Double(sample.daysAgo))
            // プレビュー用なので、作れなければ落として気づく
            let record = try! store.add(image: makeImage(color: sample.color), takenAt: takenAt)
            store.setGenre(sample.genre, for: record)
            if sample.isFavorite {
                store.toggleFavorite(record)
            }
            store.setTags(sample.tags, for: record)
            if sample.genre == .unsorted {
                store.saveSuggestion(genre: .food, tags: [.ramen, .noodles, .chinese], for: record.id)
            }
        }
        return container
    }

    /// 写真の代わりに使う単色の画像（プレビュー用）。
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

    /// 前回のプレビューのファイルが溜まらないよう、プロセスで1回だけ一時フォルダを消す。
    /// 呼ぶたびに消すと、同時に開いている別のプレビューの写真まで消えてしまう。
    private static let cleanedPhotoDirectory: Void = {
        try? FileManager.default.removeItem(at: photoStorage.directory)
    }()
}
