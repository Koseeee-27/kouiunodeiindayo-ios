import SwiftData
import SwiftUI

@main
struct KouiunodeiindayoApp: App {
    /// 提案の問い合わせ（機能26）。問い合わせ中の控えをアプリ全体で1つにするため、ここで1つだけ作って渡す
    @State private var suggestionService = LiveSuggestionService()

    var body: some Scene {
        WindowGroup {
            LaunchSplashView {
                RootView()
            }
            .environment(\.suggestionService, suggestionService)
            // 文字の種類を指定していない本文・ボタンも、アプリの文字にする
            .font(Theme.font(.body))
        }
        // 自前で `ModelContainer` を作らない（作成失敗時の `fatalError` を書かずに済む）
        .modelContainer(for: Record.self)
    }
}
