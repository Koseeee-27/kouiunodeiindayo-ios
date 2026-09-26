import SwiftData
import SwiftUI

@main
struct KouiunodeiindayoApp: App {
    var body: some Scene {
        WindowGroup {
            LaunchSplashView {
                RootView()
            }
            // 文字の種類を指定していない本文・ボタンも、アプリの文字にする
            .font(Theme.font(.body))
        }
        // 自前で `ModelContainer` を作らない（作成失敗時の `fatalError` を書かずに済む）
        .modelContainer(for: Record.self)
    }
}
