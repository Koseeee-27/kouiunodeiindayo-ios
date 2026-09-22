import SwiftData
import SwiftUI

@main
struct KouiunodeiindayoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // 自前で `ModelContainer` を作らない（作成失敗時の `fatalError` を書かずに済む）
        .modelContainer(for: Record.self)
    }
}
