import Foundation

enum SummarizationError: Error, LocalizedError {
    case timeout
    case allEnginesFailed

    var errorDescription: String? {
        switch self {
        case .timeout:
            String(localized: "Summarization timed out")
        case .allEnginesFailed:
            String(localized: "All summarization engines failed")
        }
    }
}

/// Three-tier summarization dispatcher: Apple Foundation Models -> MLX -> Extractive.
/// Automatically selects the best available engine and falls back on failure.
final class SummarizationEngine: SummarizationServiceProtocol, Sendable {

    private let chunker: TranscriptChunker

    init(chunker: TranscriptChunker = TranscriptChunker()) {
        self.chunker = chunker
    }

    // MARK: - Availability Checks

    nonisolated static var isAppleFoundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return true
        }
        #endif
        return false
    }

    nonisolated static var isMLXAvailable: Bool {
        #if canImport(MLXLLM)
        return MLXSummarizationService.isModelCached
        #else
        return MLXSummarizationServiceStub.isModelCached
        #endif
    }

    nonisolated static var currentEngineName: String {
        if isAppleFoundationModelsAvailable {
            return String(localized: "Apple AI")
        } else if isMLXAvailable {
            return String(localized: "MLX Qwen")
        } else {
            return String(localized: "Basic")
        }
    }

    // MARK: - SummarizationServiceProtocol

    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO {
        // Tier 1: Apple Foundation Models
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            do {
                let service = AppleFoundationModelsSummarizationService()
                return try await summarizeWithChunking(
                    transcript: transcript,
                    using: service
                )
            } catch {
                // Fall through to next tier
            }
        }
        #endif

        // Tier 2: MLX with timeout
        #if canImport(MLXLLM)
        if Self.isMLXAvailable {
            do {
                let service = MLXSummarizationService()
                return try await withTimeout(seconds: 120) {
                    try await self.summarizeWithChunking(
                        transcript: transcript,
                        using: service
                    )
                }
            } catch {
                // Fall through to extractive
            }
        }
        #endif

        // Tier 3: Extractive (always succeeds)
        return try await ExtractiveSummarizationService().summarize(transcript: transcript)
    }

    // MARK: - Chunked Summarization

    private func summarizeWithChunking(
        transcript: [TranscriptSegmentDTO],
        using service: any SummarizationServiceProtocol
    ) async throws -> MeetingSummaryDTO {
        let chunks = chunker.chunk(segments: transcript)

        guard chunks.count > 1 else {
            return try await service.summarize(transcript: transcript)
        }

        // Summarize each chunk independently
        var chunkSummaries: [MeetingSummaryDTO] = []
        for chunk in chunks {
            let summary = try await service.summarize(transcript: chunk)
            chunkSummaries.append(summary)
        }

        // Merge: create a meta-transcript from chunk summaries and summarize again
        let metaTranscript = chunkSummaries.enumerated().map { index, summary in
            TranscriptSegmentDTO(
                startTime: Double(index),
                endTime: Double(index + 1),
                text: "Part \(index + 1): \(summary.summary) Key points: \(summary.keyPoints.joined(separator: "; ")). Action items: \(summary.actionItems.joined(separator: "; "))"
            )
        }

        return try await service.summarize(transcript: metaTranscript)
    }

    // MARK: - Timeout

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw SummarizationError.timeout
            }

            guard let result = try await group.next() else {
                throw SummarizationError.allEnginesFailed
            }
            group.cancelAll()
            return result
        }
    }
}
