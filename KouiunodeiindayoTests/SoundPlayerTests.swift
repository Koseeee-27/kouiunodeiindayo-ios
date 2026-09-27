import Foundation
import Testing

@testable import Kouiunodeiindayo

@MainActor
struct SoundPlayerTests {
    @Test func 効果音のファイルがアプリに入っている() {
        #expect(
            Bundle.main.url(
                forResource: SoundPlayer.Sound.stampPress.rawValue, withExtension: SoundPlayer.fileExtension) != nil)
    }
}
