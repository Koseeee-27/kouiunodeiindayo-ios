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
}
