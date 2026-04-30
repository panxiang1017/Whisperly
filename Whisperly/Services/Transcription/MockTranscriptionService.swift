import Foundation

final class MockTranscriptionService: TranscriptionServiceProtocol, Sendable {
    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegmentDTO] {
        try await Task.sleep(for: .seconds(2))

        return [
            TranscriptSegmentDTO(startTime: 0.0, endTime: 5.2, text: String(localized: "Good morning everyone, let's get started with today's meeting.")),
            TranscriptSegmentDTO(startTime: 5.5, endTime: 12.0, text: String(localized: "Sure. I wanted to discuss the project timeline and upcoming milestones.")),
            TranscriptSegmentDTO(startTime: 12.5, endTime: 20.1, text: String(localized: "We're currently on track for the Phase 1 delivery. The architecture is solid.")),
            TranscriptSegmentDTO(startTime: 20.5, endTime: 28.0, text: String(localized: "Great. What about the testing coverage? Are we meeting our targets?")),
            TranscriptSegmentDTO(startTime: 28.5, endTime: 35.8, text: String(localized: "Yes, we have over 80% coverage on the core modules. I'll share the report after the meeting.")),
            TranscriptSegmentDTO(startTime: 36.0, endTime: 42.0, text: String(localized: "Perfect. Let's move on to the action items from last week.")),
        ]
    }
}
