import Foundation
import SwiftData
import UIKit

@testable import Kouiunodeiindayo

/// テスト用の RecordStore。メモリ上のコンテナと、テストごとの一時フォルダに写真を書く。
/// `ModelContext` はコンテナが生きている間だけ使えるので、コンテナも一緒に持つ。
@MainActor
struct TestStore {
    let container: ModelContainer
    let photoStorage: PhotoStorage
    let store: RecordStore

    init() {
        container = SampleData.makeContainer()
        photoStorage = PhotoStorage(directory: URL.temporaryDirectory.appending(path: "Tests-\(UUID().uuidString)"))
        store = RecordStore(modelContext: container.mainContext, photoStorage: photoStorage)
    }

    /// 仕分け待ちの記録を1件作る。
    func addRecord() throws -> Record {
        try store.add(image: SampleData.makeImage(color: .systemOrange), takenAt: .now)
    }

    func allRecords() throws -> [Record] {
        try container.mainContext.fetch(FetchDescriptor<Record>())
    }
}
