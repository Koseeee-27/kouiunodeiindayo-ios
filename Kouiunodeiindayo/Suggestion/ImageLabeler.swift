import Foundation
import Vision

/// Vision で取れたラベル1つ。Worker に送る形（名前の絞り込み・並べ替え・丸め）は `SuggestionRequest` でかける。
nonisolated struct ImageLabel: Equatable, Sendable {
    /// Vision のラベルの identifier（英語の名前。例 `ramen`）。
    let name: String
    /// 確信度（0〜1）。
    let confidence: Float
}

/// 写真から Vision のラベルを取る。端末の中だけで動き、写真そのものは外に出さない（`docs/adr/0006-suggestion-vision-jev.md`）。
enum ImageLabeler {
    /// 写真ファイルのラベルを取る。メインスレッドの外で動く。
    /// `UIImage` ではなく、`PhotoStorage` が保存した JPEG の場所を受け取る（向きは保存時に「上」に揃えてあるので指定しない）。
    /// 分類の一覧が全部返る（並びの保証は無い）。並べ替えと絞り込みは呼ぶ側で行う。
    @concurrent
    nonisolated static func labels(ofPhotoAt url: URL) async throws -> [ImageLabel] {
        let observations = try await ClassifyImageRequest().perform(on: url)
        return observations.map { ImageLabel(name: $0.identifier, confidence: $0.confidence) }
    }
}
