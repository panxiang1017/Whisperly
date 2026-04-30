import Foundation
import WhisperKit

/// Real transcription service powered by WhisperKit (argmax-oss-swift).
/// Downloads and caches models on-device; runs entirely on ANE/GPU.
final class WhisperKitTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private let modelManager: ModelManager

    @MainActor
    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }

    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegmentDTO] {
        let pipe = try await getOrCreatePipeline()

        var options = DecodingOptions(
            task: .transcribe,
            usePrefillPrompt: true,
            withoutTimestamps: false
        )
        if let language {
            options.language = language
        }

        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)

        return results.flatMap { result in
            (result.segments ?? []).map { segment in
                TranscriptSegmentDTO(
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
    }

    // MARK: - Pipeline Management

    private func getOrCreatePipeline() async throws -> WhisperKit {
        if let existing = whisperKit { return existing }

        let modelFolder = await modelManager.modelFolderURL.path

        let config = WhisperKitConfig(
            model: await modelManager.whisperModelName,
            modelFolder: modelFolder,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true
        )
        let pipe = try await WhisperKit(config)
        whisperKit = pipe
        return pipe
    }
}
