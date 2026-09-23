import SwiftData
import SwiftUI

/// 仕分け。中身は Issue #16 で作る。今は撮った写真が保存されたかを確かめるための仮の画面。
/// 撮ったあと（カメラのカバーの中）と、ホーム・一覧から開く。下タブには載らない。
/// 閉じるのは `dismiss()`。どこから開いても、開いた形に合わせて閉じる。
struct SortView: View {
    // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
    private static let unsorted = Genre.unsorted.rawValue

    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Record> { $0.genre == unsorted },
        sort: \Record.takenAt, order: .reverse
    )
    private var records: [Record]

    var body: some View {
        VStack(spacing: 16) {
            Text("仕分け（仮。#16 で置き換える）")
                .font(.title)
            Text("仕分け待ち \(records.count) 枚")
            if let latest = records.first {
                Text(latest.takenAt, format: .dateTime)
            }
            Button("ホームへ") {
                dismiss()
            }
            .accessibilityLabel("ホームへ戻る")
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

#Preview {
    SortView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
