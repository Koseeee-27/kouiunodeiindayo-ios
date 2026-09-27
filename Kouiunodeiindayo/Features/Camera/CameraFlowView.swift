import AVFoundation
import OSLog
import SwiftData
import SwiftUI
import UIKit

/// カメラのカバー（`RootView` の `fullScreenCover`）の中身。撮る → 保存 → 仕分けを、同じカバーの中で切り替える。
/// カバーを閉じてから仕分けを出し直すと、ホームが一瞬見えてから仕分けが上がってくるため。
/// カメラを出す前に許可の状態を見て、断られている・制限されているときは案内（`CameraAccessGuideView`）を出す（#21）。
struct CameraFlowView: View {
    enum Step: Equatable {
        /// 許可をまだ聞いていない。iOS の許可ダイアログの答えを待つ
        case requestingAccess
        case camera
        case accessGuide(isRestricted: Bool)
        /// 案内から「アルバムから選ぶ」。キャンセルで同じ文言の案内に戻るため `isRestricted` を持つ
        case library(isRestricted: Bool)
        /// 今撮った（選んだ）1枚の id。溜まっている仕分け待ちは出さない
        case sort(recordID: UUID)
    }

    private static let logger = Logger(category: "CameraFlowView")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @Environment(\.suggestionService) private var suggestionService

    @State private var step: Step
    /// 撮った写真を写真アプリにも保存するか（機能19）
    @AppStorage(PhotoLibrarySaver.storageKey) private var savesToPhotoLibrary = PhotoLibrarySaver.defaultValue
    @State private var isSaveFailed = false

    /// `step` はプレビューで仕分けや案内から始めるためだけに渡す。`nil` ならカメラの許可の状態で決める。
    init(step: Step? = nil) {
        _step = State(initialValue: step ?? Self.initialStep())
    }

    private static func initialStep() -> Step {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            .camera
        case .denied:
            .accessGuide(isRestricted: false)
        case .restricted:
            .accessGuide(isRestricted: true)
        case .notDetermined:
            // 標準カメラに任せると、ダイアログで「許可しない」を押した瞬間に真っ黒な画面になるため、先にアプリから聞く
            .requestingAccess
        @unknown default:
            .camera
        }
    }

    var body: some View {
        Group {
            switch step {
            case .requestingAccess:
                // 許可ダイアログの後ろは無地。すぐ後に出るカメラと同じ黒にする（アプリの地の色にはしない）
                Color.black
                    .ignoresSafeArea()
                    .task { await requestAccess() }
            case .camera:
                CameraView(
                    onPick: { image in save(image, source: .camera) },
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()
            case .accessGuide(let isRestricted):
                CameraAccessGuideView(
                    isRestricted: isRestricted,
                    onPickFromLibrary: { step = .library(isRestricted: isRestricted) },
                    onGoHome: { dismiss() }
                )
            case .library(let isRestricted):
                CameraView(
                    forcesPhotoLibrary: true,
                    onPick: { image in save(image, source: .photoLibrary) },
                    onCancel: { step = .accessGuide(isRestricted: isRestricted) }
                )
                .ignoresSafeArea()
            case .sort(let recordID):
                SortView(recordID: recordID)
            }
        }
        .alert("保存できませんでした", isPresented: $isSaveFailed) {
            Button("OK") {
                dismiss()
            }
        }
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        step = granted ? .camera : .accessGuide(isRestricted: false)
    }

    private func save(_ image: UIImage, source: PhotoLibrarySaver.Source) {
        do {
            // 撮影日時は常に今。アルバムから選んだ写真も、写真の撮影日時ではなく選んだ時刻にする（`docs/data-model.md`）
            let store = RecordStore(modelContext: modelContext, photoStorage: photoStorage)
            let record = try store.add(image: image, takenAt: .now)
            // 提案は裏で問い合わせる。仕分けの画面は待たずに出す（`docs/architecture.md`「提案（機能26）の流れ」）
            suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
            // 写真アプリへの保存も裏で行う。仕分けの画面は待たずに出し、断られた・失敗したときも止めない（機能19）
            if PhotoLibrarySaver.shouldSave(source: source, isEnabled: savesToPhotoLibrary) {
                Task { await PhotoLibrarySaver.save(image) }
            }
            step = .sort(recordID: record.id)
        } catch {
            Self.logger.error("撮った写真を保存できなかった: \(error.localizedDescription, privacy: .public)")
            isSaveFailed = true
        }
    }
}

// 許可の状態で決めると、プレビューでは未確認のため黒い画面になる。カメラの段を直接出す
#Preview("カメラ") {
    CameraFlowView(step: .camera)
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

#Preview("案内（断られた）") {
    CameraFlowView(step: .accessGuide(isRestricted: false))
        .modelContainer(SampleData.makePreviewContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
}

// 仕分け待ちが3件ある中で、今撮った1枚に見立てた1件だけを出す
#Preview("仕分け") {
    let container = SortPreviewData.makeManyUnsortedContainer()
    CameraFlowView(step: .sort(recordID: SortPreviewData.newestUnsortedID(in: container)))
        .modelContainer(container)
        .environment(\.photoStorage, SampleData.photoStorage)
}
