import OSLog
import SwiftData
import SwiftUI

/// 開いたときの画面。ここでカメラ／ホーム／一覧の切り替えを持つ予定。
/// 今はデータ層の動作確認だけができる仮の画面で、本物の RootView の Issue で丸ごと置き換える。
struct RootView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("こういうのでいいんだよ")
                .font(.title)
            #if DEBUG
            DataLayerDebugView()
            #endif
        }
        .padding()
    }
}

#if DEBUG
/// データ層（記録の追加・削除、写真ファイルの作成・削除）を手で確かめるための仮の画面。
private struct DataLayerDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @Query(sort: \Record.takenAt, order: .reverse) private var records: [Record]

    private static let logger = Logger(category: "DataLayerDebugView")

    var body: some View {
        VStack(spacing: 16) {
            Text("記録: \(records.count) 件")
            if let latest = records.first, let thumbnail = photoStorage.thumbnail(id: latest.id) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }
            Button("サンプルを1件追加") { addSample() }
            Button("すべて消す") { deleteAll() }
        }
    }

    private var store: RecordStore {
        RecordStore(modelContext: modelContext, photoStorage: photoStorage)
    }

    private func addSample() {
        do {
            try store.add(image: SampleData.makeImage(color: .systemOrange), takenAt: .now)
        } catch {
            Self.logger.error("サンプルを追加できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteAll() {
        do {
            try store.deleteAll()
        } catch {
            Self.logger.error("すべて消せなかった: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif

#Preview {
    RootView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
