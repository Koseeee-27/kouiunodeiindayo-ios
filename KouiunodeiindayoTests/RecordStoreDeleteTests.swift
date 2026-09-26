import Foundation
import Testing

@testable import Kouiunodeiindayo

/// 一覧の選ぶモードで、まとめて消す（#118）
@MainActor
struct RecordStoreDeleteTests {
    private func photoExists(_ record: (id: UUID, fileName: String), in context: TestStore) -> Bool {
        FileManager.default.fileExists(
            atPath: context.photoStorage.photoURL(fileName: record.fileName).path(percentEncoded: false))
    }

    @Test func 三件のうち二件を消すと一件残り二件の写真とサムネイルが消える() throws {
        let context = TestStore()
        let a = try context.addRecord()
        let b = try context.addRecord()
        let c = try context.addRecord()
        let files = [a, b, c].map { (id: $0.id, fileName: $0.photoFileName) }
        #expect(files.allSatisfy { photoExists($0, in: context) })
        #expect(context.photoStorage.thumbnail(id: a.id) != nil)

        try context.store.delete([a, c])

        let remaining = try context.allRecords()
        #expect(remaining.map(\.id) == [files[1].id])
        #expect(!photoExists(files[0], in: context))
        #expect(!photoExists(files[2], in: context))
        #expect(context.photoStorage.thumbnail(id: files[0].id) == nil)
        #expect(context.photoStorage.thumbnail(id: files[2].id) == nil)
        // 残した記録の写真とサムネイルは消えない
        #expect(photoExists(files[1], in: context))
        #expect(context.photoStorage.thumbnail(id: files[1].id) != nil)
    }

    @Test func 空の配列は何もしない() throws {
        let context = TestStore()
        let a = try context.addRecord()

        try context.store.delete([Record]())

        #expect(try context.allRecords().map(\.id) == [a.id])
        #expect(photoExists((a.id, a.photoFileName), in: context))
    }

    @Test func 全部を消せる() throws {
        let context = TestStore()
        let records = [try context.addRecord(), try context.addRecord()]

        try context.store.delete(records)

        #expect(try context.allRecords().isEmpty)
    }
}
