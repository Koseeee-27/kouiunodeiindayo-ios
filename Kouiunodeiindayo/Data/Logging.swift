import Foundation
import OSLog

extension Logger {
    /// アプリ共通の subsystem でロガーを作る。
    /// subsystem は個人ごとに変わるバンドル ID なので、取れなければアプリ名に倒す。
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "Kouiunodeiindayo", category: category)
    }
}
