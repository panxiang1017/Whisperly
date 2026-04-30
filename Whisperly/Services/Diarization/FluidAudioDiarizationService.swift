import Foundation
import FluidAudio

/// Real speaker diarization service powered by FluidAudio (Sortformer + speaker embedding).
/// Runs entirely on-device via Core ML / ANE.
final class FluidAudioDiarizationService: DiarizationServiceProtocol, @unchecked Sendable {
    private static let speakerColors = [
        "007AFF", "FF9500", "34C759", "FF3B30", "AF52DE", "FF2D55"
    ]

    func diarize(
        audioURL: URL,
        segments: [TranscriptSegmentDTO]
    ) async throws -> ([TranscriptSegmentDTO], [SpeakerDTO]) {
        guard !segments.isEmpty else { return (segments, []) }

        // Run FluidAudio offline diarization pipeline for best accuracy.
        let diarizer = try await Diarizer()
        let diarizationResult = try await diarizer.diarize(audioFile: audioURL)

        // Build speaker map: FluidAudio speaker index → our SpeakerDTO
        var speakerMap: [Int: SpeakerDTO] = [:]

        for label in diarizationResult.labels {
            if speakerMap[label.speaker] == nil {
                let index = speakerMap.count
                let colorHex = Self.speakerColors[index % Self.speakerColors.count]
                speakerMap[label.speaker] = SpeakerDTO(
                    label: String(localized: "Speaker \(index + 1)"),
                    colorHex: colorHex
                )
            }
        }

        // Assign speaker IDs to transcript segments by matching timestamps.
        let diarizedSegments = segments.map { segment -> TranscriptSegmentDTO in
            let segmentMidpoint = (segment.startTime + segment.endTime) / 2.0

            // Find the diarization label that best overlaps with this segment.
            let bestLabel = diarizationResult.labels.max(by: { a, b in
                overlapDuration(a, with: segment) < overlapDuration(b, with: segment)
            })

            let speakerID: UUID? = {
                guard let label = bestLabel,
                      overlapDuration(label, with: segment) > 0
                else { return nil }
                return speakerMap[label.speaker]?.id
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

    // MARK: - Helpers

    private func overlapDuration(_ label: DiarizationLabel, with segment: TranscriptSegmentDTO) -> Double {
        let overlapStart = max(label.start, segment.startTime)
        let overlapEnd = min(label.end, segment.endTime)
        return max(0, overlapEnd - overlapStart)
    }
}
