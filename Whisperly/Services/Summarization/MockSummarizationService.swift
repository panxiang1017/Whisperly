import Foundation

final class MockSummarizationService: SummarizationServiceProtocol, Sendable {
    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO {
        try await Task.sleep(for: .seconds(1))

        return MeetingSummaryDTO(
            summary: String(localized: "The team discussed the current project timeline and confirmed Phase 1 delivery is on track. Testing coverage exceeds 80% on core modules. Action items from the previous meeting were reviewed."),
            keyPoints: [
                String(localized: "Phase 1 delivery is on schedule"),
                String(localized: "Architecture review completed successfully"),
                String(localized: "Testing coverage exceeds 80% on core modules"),
            ],
            actionItems: [
                String(localized: "Share testing coverage report with the team"),
                String(localized: "Review and update project timeline for Phase 2"),
                String(localized: "Schedule follow-up meeting for next week"),
            ]
        )
    }
}
