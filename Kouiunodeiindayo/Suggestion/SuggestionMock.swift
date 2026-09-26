import Foundation
import SwiftData
import SwiftUI

/// 通信せずに、決まった提案を返すモック。プレビューで使う（Worker・Vision を呼ばない）。
struct SuggestionMock: SuggestionService {
    /// 返す提案。`nil` は何もしない（通信できない・未設定と同じで、何も保存しない）。
    let result: SuggestionResult?
    /// 提案が後から届く様子を見るための待ち時間。
    var delay: Duration = .milliseconds(300)

    /// 何もしない。`@Environment` の既定値。
    static let disabled = SuggestionMock(result: nil)
    /// ラーメンの写真に見立てた提案。おまかせに任せられる確率
    static let ramen = SuggestionMock(
        result: SuggestionResult(genre: .food, genreConfidence: 0.95, tags: [.ramen, .noodles, .chinese]))
    /// ラーメンだが自信が無い（おまかせに任せない確率）。
    static let ramenUnsure = SuggestionMock(
        result: SuggestionResult(genre: .food, genreConfidence: 0.6, tags: [.ramen, .noodles, .chinese]))
    /// 提案なし（Worker が自信が低いと返したとき）。問い合わせ済みにはなる。
    static let noSuggestion = SuggestionMock(result: .empty)

    /// 待たずに、その場で保存する版。プレビューの静止画（スナップショット）は開いた直後に撮られ、
    /// 裏で保存するのを待たないので、確認用のプレビューではこれを使う。
    var immediate: SuggestionMock {
        SuggestionMock(result: result, delay: .zero)
    }

    func requestSuggestion(for id: UUID, photoFileName: String, store: RecordStore) {
        guard let result else { return }
        guard delay > .zero else {
            store.saveSuggestion(
                genre: result.genre, genreConfidence: result.genreConfidence, tags: result.tags, for: id)
            return
        }
        Task {
            try? await Task.sleep(for: delay)
            store.saveSuggestion(
                genre: result.genre, genreConfidence: result.genreConfidence, tags: result.tags, for: id)
        }
    }
}

/// 提案が保存されたかを確かめるための、プレビュー専用の一覧。仕分け待ちの記録ごとに、保存された提案を文字で並べる。
/// 開いたときに、仕分けの画面と同じく `suggestedAt` が `nil` の記録を問い合わせる。アプリの画面からは使わない。
struct SuggestionCheckView: View {
    private static let unsorted = Genre.unsorted.rawValue

    @Environment(\.modelContext) private var modelContext
    @Environment(\.photoStorage) private var photoStorage
    @Environment(\.suggestionService) private var suggestionService
    @Query private var records: [Record]

    init() {
        // `#Predicate` の中に `Genre.unsorted.rawValue` を直接書けないので、先に値に取り出す
        let unsorted = Self.unsorted
        _records = Query(filter: #Predicate<Record> { $0.genre == unsorted }, sort: \Record.takenAt, order: .reverse)
    }

    var body: some View {
        List(records) { record in
            HStack(spacing: 12) {
                RecordPhotoView(record: record, kind: .thumbnail)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.takenAt, format: .dateTime.month().day().hour().minute())
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Self.summary(of: record))
                        .font(Theme.font(.body))
                }
            }
        }
        .onAppear {
            let store = RecordStore(modelContext: modelContext, photoStorage: photoStorage)
            for record in records where record.suggestedAt == nil {
                suggestionService.requestSuggestion(for: record.id, photoFileName: record.photoFileName, store: store)
            }
        }
    }

    private static func summary(of record: Record) -> String {
        guard record.suggestedAt != nil else { return "未問い合わせ" }
        let genre = record.suggestedGenreValue?.title
        let tags = record.suggestedTagValues.map(\.title)
        if genre == nil && tags.isEmpty {
            return "提案なし（問い合わせ済み）"
        }
        return ([genre ?? "ジャンルなし"] + tags).joined(separator: "・")
    }
}

// 仕分け待ち3件のうち、1件はサンプルデータで提案済み。残りの2件にモックの提案が入る
#Preview("ラーメンの提案") {
    SuggestionCheckView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.ramen.immediate)
}

#Preview("提案なし") {
    SuggestionCheckView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.noSuggestion.immediate)
}

#Preview("通信できない") {
    SuggestionCheckView()
        .modelContainer(SortPreviewData.makeManyUnsortedContainer())
        .environment(\.photoStorage, SampleData.photoStorage)
        .environment(\.suggestionService, SuggestionMock.disabled)
}
