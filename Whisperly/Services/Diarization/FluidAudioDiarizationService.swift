import Foundation
import FluidAudio

/// Real speaker diarization service powered by FluidAudio (Sortformer + speaker embedding).
/// Runs entirely on-device via Core ML / ANE.
final class FluidAudioDiarizationService: DiarizationServiceProtocol, @unchecked Sendable {
    private static let speakerColors = [
        "007AFF", "FF9500", "34C759", "FF3B30", "AF52DE", "FF2D55"
    ]

    private var manager: OfflineDiarizerManager?

    func diarize(
        audioURL: URL,
        segments: [TranscriptSegmentDTO]
    ) async throws -> ([TranscriptSegmentDTO], [SpeakerDTO]) {
        guard !segments.isEmpty else { return (segments, []) }

        let diarizer = try await getOrCreateManager()
        let diarizationResult = try await diarizer.process(audioURL)

        // Build speaker map: FluidAudio speakerId string → our SpeakerDTO
        var speakerMap: [String: SpeakerDTO] = [:]

        for timedSegment in diarizationResult.segments {
            if speakerMap[timedSegment.speakerId] == nil {
                let index = speakerMap.count
                let colorHex = Self.speakerColors[index % Self.speakerColors.count]
                speakerMap[timedSegment.speakerId] = SpeakerDTO(
                    label: String(localized: "Speaker \(index + 1)"),
                    colorHex: colorHex
                )
            }
        }

        // Assign speaker IDs to transcript segments by matching timestamps.
        let diarizedSegments = segments.map { segment -> TranscriptSegmentDTO in
            // Find the diarization label that best overlaps with this segment.
            let bestMatch = diarizationResult.segments.max(by: { a, b in
                overlapDuration(a, with: segment) < overlapDuration(b, with: segment)
            })

            let speakerID: UUID? = {
                guard let match = bestMatch,
                      overlapDuration(match, with: segment) > 0
                else { return nil }
                return speakerMap[match.speakerId]?.id
            }()

            return TranscriptSegmentDTO(
                id: segment.id,
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: segment.text,
                speakerID: speakerID
            )
        }

        let speakers = speakerMap.values.sorted { $0.label < $1.label }
        return (diarizedSegments, Array(speakers))
    }

    // MARK: - Manager

    private func getOrCreateManager() async throws -> OfflineDiarizerManager {
        if let existing = manager { return existing }

        let mgr = OfflineDiarizerManager()
        let models = try await OfflineDiarizerModels.load()
        mgr.initialize(models: models)
        manager = mgr
        return mgr
    }

    // MARK: - Helpers

    private func overlapDuration(_ timedSeg: TimedSpeakerSegment, with segment: TranscriptSegmentDTO) -> Double {
        let overlapStart = max(Double(timedSeg.startTimeSeconds), segment.startTime)
        let overlapEnd = min(Double(timedSeg.endTimeSeconds), segment.endTime)
        return max(0, overlapEnd - overlapStart)
    }
}
