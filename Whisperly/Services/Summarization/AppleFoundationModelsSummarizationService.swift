#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26, macOS 26, *)
final class AppleFoundationModelsSummarizationService: SummarizationServiceProtocol, Sendable {

    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO {
        let session = LanguageModelSession()
        let transcriptText = transcript.map(\.text).joined(separator: "\n")

        let prompt = buildPrompt(for: transcriptText)
        let response = try await session.respond(to: prompt)
        let text = response.content

        return parseResponse(text) ?? MeetingSummaryDTO(
            summary: text,
            keyPoints: [],
            actionItems: [],
            engineType: .appleFoundationModels
        )
    }

    private func buildPrompt(for transcript: String) -> String {
        let isChinese = transcript.range(of: "\\p{Han}", options: .regularExpression) != nil
            && transcript.filter({ $0.isLetter }).count > 0
            && Double(transcript.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count) / max(1.0, Double(transcript.unicodeScalars.filter { $0.isASCII && $0.properties.isAlphabetic }.count)) > 0.3

        if isChinese {
            return """
            你是一个会议助手。请总结以下会议记录。

            会议记录：
            \(transcript)

            请提供：
            1. 简洁摘要（2-3段）
            2. 关键要点（3-7条）
            3. 待办事项（如能识别则标注负责人）

            以JSON格式输出：
            {"summary": "...", "keyPoints": ["..."], "actionItems": ["..."]}
            """
        }

        return """
        You are a meeting assistant. Summarize the following meeting transcript.

        Transcript:
        \(transcript)

        Provide:
        1. A concise summary (2-3 paragraphs)
        2. Key points (bullet list, 3-7 items)
        3. Action items with assignees if identifiable

        Format as JSON:
        {"summary": "...", "keyPoints": ["..."], "actionItems": ["..."]}
        """
    }

    private func parseResponse(_ text: String) -> MeetingSummaryDTO? {
        // Try to extract JSON from the response
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}")
        else { return nil }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else { return nil }

        struct SummaryJSON: Decodable {
            let summary: String?
            let keyPoints: [String]?
            let actionItems: [String]?
        }

        guard let parsed = try? JSONDecoder().decode(SummaryJSON.self, from: data) else {
            return nil
        }

        return MeetingSummaryDTO(
            summary: parsed.summary ?? "",
            keyPoints: parsed.keyPoints ?? [],
            actionItems: parsed.actionItems ?? [],
            engineType: .appleFoundationModels
        )
    }
}
#endif
