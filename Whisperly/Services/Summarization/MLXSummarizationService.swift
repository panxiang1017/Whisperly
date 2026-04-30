#if canImport(MLXLLM)
import Foundation
import MLXLLM
import MLXLMCommon

final class MLXSummarizationService: SummarizationServiceProtocol, @unchecked Sendable {

    private static let modelID = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO {
        let transcriptText = transcript.map(\.text).joined(separator: "\n")
        let prompt = buildPrompt(for: transcriptText)

        let configuration = ModelConfiguration.configuration(id: Self.modelID)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)

        let result = try await container.perform { [prompt] context in
            let input = try await context.processor.prepare(
                input: .init(messages: [["role": "user", "content": prompt]])
            )
            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: 0.3),
                context: context
            ) { tokens in
                tokens.count >= 1024 ? .stop : .more
            }
        }

        let text = result.output
        return parseResponse(text) ?? MeetingSummaryDTO(
            summary: text,
            keyPoints: [],
            actionItems: [],
            engineType: .mlx
        )
    }

    private func buildPrompt(for transcript: String) -> String {
        """
        You are a meeting assistant. Summarize this meeting transcript concisely.

        Transcript:
        \(transcript)

        Respond ONLY with JSON:
        {"summary": "2-3 paragraph summary", "keyPoints": ["point1", "point2", ...], "actionItems": ["item1", "item2", ...]}
        """
    }

    private func parseResponse(_ text: String) -> MeetingSummaryDTO? {
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
            engineType: .mlx
        )
    }

    /// Check if the MLX model files exist in the hub cache.
    nonisolated static var isModelCached: Bool {
        let fm = FileManager.default
        guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return false
        }
        let modelDir = cacheDir
            .appendingPathComponent("huggingface/models")
            .appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "--"))
        return fm.fileExists(atPath: modelDir.path)
    }
}
#else
// Stub when MLXLLM is not available
enum MLXSummarizationServiceStub {
    static let isModelCached = false
}
#endif
