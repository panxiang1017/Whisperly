import Foundation

protocol DiarizationServiceProtocol: Sendable {
    func diarize(audioURL: URL, segments: [TranscriptSegmentDTO]) async throws -> ([TranscriptSegmentDTO], [SpeakerDTO])
}
