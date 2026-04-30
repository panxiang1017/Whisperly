import Foundation

final class MockDiarizationService: DiarizationServiceProtocol, Sendable {
    private static let speakerColors = ["007AFF", "FF9500", "34C759", "FF3B30", "AF52DE"]

    func diarize(audioURL: URL, segments: [TranscriptSegmentDTO]) async throws -> ([TranscriptSegmentDTO], [SpeakerDTO]) {
        let speakerCount = min(3, max(1, segments.count / 2))
        let speakers = (0..<speakerCount).map { index in
            SpeakerDTO(
                label: String(localized: "Speaker \(index + 1)"),
                colorHex: Self.speakerColors[index % Self.speakerColors.count]
            )
        }

        let diarizedSegments = segments.enumerated().map { index, segment in
            let speakerIndex = index % speakerCount
            return TranscriptSegmentDTO(
                id: segment.id,
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: segment.text,
                speakerID: speakers[speakerIndex].id
            )
        }

        return (diarizedSegments, speakers)
    }
}
