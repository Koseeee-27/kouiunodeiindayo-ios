import Foundation

/// 開いたときの画面（機能25）。保存する値は `docs/data-model.md` の「設定値」が正。
enum LaunchScreen: String {
    case camera
    case home

    /// `@AppStorage` と `UserDefaults` で共通に使うキー。文字列をここ1か所だけに置く。
    static let storageKey = "launchScreen"

    /// 保存されている設定。未設定・知らない文字列はカメラに倒す（初期設定がカメラのため）。
    static var stored: LaunchScreen {
        let value = UserDefaults.standard.string(forKey: storageKey)
        return value.flatMap(LaunchScreen.init(rawValue:)) ?? .camera
    }
}
