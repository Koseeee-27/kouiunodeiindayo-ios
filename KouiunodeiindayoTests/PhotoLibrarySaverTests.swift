import Testing

@testable import Kouiunodeiindayo

/// 撮った写真を写真アプリにも保存するか（機能19・#138）
@MainActor
struct PhotoLibrarySaverTests {
    @Test func カメラで撮って設定がオンなら保存する() {
        #expect(PhotoLibrarySaver.shouldSave(source: .camera, isEnabled: true))
    }

    @Test func 設定がオフなら保存しない() {
        #expect(!PhotoLibrarySaver.shouldSave(source: .camera, isEnabled: false))
    }

    @Test func アルバムから選んだ写真は保存しない() {
        #expect(!PhotoLibrarySaver.shouldSave(source: .photoLibrary, isEnabled: true))
        #expect(!PhotoLibrarySaver.shouldSave(source: .photoLibrary, isEnabled: false))
    }

    @Test func 初期設定はオン() {
        #expect(PhotoLibrarySaver.defaultValue)
        #expect(PhotoLibrarySaver.storageKey == "savesToPhotoLibrary")
    }

    // MARK: 選んで保存したときの知らせ

    @Test func 全部保存できたら枚数を出す() {
        #expect(PhotoLibrarySaver.message(for: .finished(saved: 3, failed: 0)) == "3 枚を保存しました")
        #expect(PhotoLibrarySaver.message(for: .finished(saved: 1, failed: 0)) == "1 枚を保存しました")
    }

    @Test func 一部失敗したら失敗の枚数も出す() {
        #expect(
            PhotoLibrarySaver.message(for: .finished(saved: 2, failed: 1)) == "2 枚を保存しました（1 枚は保存できませんでした）")
    }

    @Test func 全部失敗したら保存できなかったと出す() {
        #expect(PhotoLibrarySaver.message(for: .finished(saved: 0, failed: 2)) == "保存できませんでした")
    }

    @Test func 許可を断られたら設定から許可するよう出す() {
        #expect(PhotoLibrarySaver.message(for: .denied) == "設定から写真への追加を許可してください")
    }
}
