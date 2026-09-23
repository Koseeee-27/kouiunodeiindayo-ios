import OSLog
import SwiftData
import SwiftUI
import UIKit

/// カメラのカバー（`RootView` の `fullScreenCover`）の中身。撮る → 保存 → 仕分けを、同じカバーの中で切り替える。
/// カバーを閉じてから仕分けを出し直すと、ホームが一瞬見えてから仕分けが上がってくるため。
struct CameraFlowView: View {
    enum Step {
        case camera
        case sort
    }

    private static let logger = Logger(category: "CameraFlowView")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage

    @State private var step: Step
    @State private var isSaveFailed = false

    /// `step` はプレビューで仕分けから始めるためだけに渡す。
    init(step: Step = .camera) {
        _step = State(initialValue: step)
    }

    var body: some View {
        Group {
            switch step {
            case .camera:
                CameraView(
                    onPick: { image in save(image) },
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()
            case .sort:
                SortView()
            }
        }
        .alert("保存できませんでした", isPresented: $isSaveFailed) {
            Button("OK") {
                dismiss()
            }
        }
    }

    private func save(_ image: UIImage) {
        do {
            // 撮影日時は常に今。写真の撮影日時を使うのはカメラロールからの取り込み（機能18）だけ
            try RecordStore(modelContext: modelContext, photoStorage: photoStorage).add(image: image, takenAt: .now)
            step = .sort
        } catch {
            Self.logger.error("撮った写真を保存できなかった: \(error.localizedDescription, privacy: .public)")
            isSaveFailed = true
        }
    }
}

#Preview("カメラ") {
    CameraFlowView()
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("仕分け（仮）") {
    CameraFlowView(step: .sort)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}
