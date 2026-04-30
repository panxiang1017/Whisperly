import Foundation

protocol SummarizationServiceProtocol: Sendable {
    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO
}
