import Foundation
import Speech
import AVFoundation
import CoreMedia

/// Transcription service powered by macOS 26 SpeechAnalyzer + SpeechTranscriber.
/// Uses system-level ASR — no app-bundled model downloads required.
final class SpeechAnalyzerTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {

    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegmentDTO] {
        let locale = Locale(identifier: language ?? Locale.current.identifier)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        // Download language assets if needed (system-managed, transparent to user).
        if let installer = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installer.downloadAndInstall()
        }

        let file = try AVAudioFile(forReading: audioURL)
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: file,
            modules: [transcriber],
            finishAfterFile: true
        )

        var segments: [TranscriptSegmentDTO] = []
        for try await result in transcriber.results {
            let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let startTime = result.range.start.seconds
            let endTime = (result.range.start + result.range.duration).seconds

            segments.append(
                TranscriptSegmentDTO(
                    startTime: startTime,
                    endTime: endTime,
                    text: text
                )
            )
        }

        _ = analyzer // keep analyzer alive until results are consumed

        return segments
    }
}
