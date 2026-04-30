import Testing
import Foundation
import SwiftData
@testable import Whisperly

@Suite("Summarization Engine Tests")
struct SummarizationEngineTests {

    private func makeSegments() -> [TranscriptSegmentDTO] {
        [
            TranscriptSegmentDTO(startTime: 0, endTime: 10, text: "The team discussed the project timeline and agreed on deliverables."),
            TranscriptSegmentDTO(startTime: 10, endTime: 20, text: "We need to complete the database migration before Friday."),
            TranscriptSegmentDTO(startTime: 20, endTime: 30, text: "John will prepare the testing report and share it."),
            TranscriptSegmentDTO(startTime: 30, endTime: 40, text: "Performance improvements were observed after the optimization."),
            TranscriptSegmentDTO(startTime: 40, endTime: 50, text: "The budget was approved by the finance team."),
        ]
    }

    @Test("Engine falls back to extractive on current hardware")
    func fallbackToExtractive() async throws {
        let engine = SummarizationEngine()
        let segments = makeSegments()

        let result = try await engine.summarize(transcript: segments)

        // On current hardware (no Apple FM, no MLX model), should fall back to extractive
        #expect(result.engineType == .extractive)
        #expect(!result.summary.isEmpty)
        #expect(!result.keyPoints.isEmpty)
    }

    @Test("Engine produces action items from transcript with action verbs")
    func engineProducesActionItems() async throws {
        let engine = SummarizationEngine()
        let segments = makeSegments()

        let result = try await engine.summarize(transcript: segments)

        // "need to" and "will prepare" should be detected
        #expect(!result.actionItems.isEmpty)
    }

    @Test("Engine handles empty transcript")
    func emptyTranscript() async throws {
        let engine = SummarizationEngine()

        let result = try await engine.summarize(transcript: [])

        #expect(result.engineType == .extractive)
        #expect(result.summary.isEmpty)
    }

    @Test("SummarizationEngineType raw values are stable")
    func engineTypeRawValues() {
        #expect(SummarizationEngineType.appleFoundationModels.rawValue == "appleFoundationModels")
        #expect(SummarizationEngineType.mlx.rawValue == "mlx")
        #expect(SummarizationEngineType.extractive.rawValue == "extractive")
        #expect(SummarizationEngineType.mock.rawValue == "mock")
    }

    @Test("MeetingSummaryDTO default engine type is mock")
    func defaultEngineType() {
        let dto = MeetingSummaryDTO(
            summary: "test",
            keyPoints: ["a"],
            actionItems: ["b"]
        )

        #expect(dto.engineType == .mock)
    }

    @Test("MeetingSummaryDTO with explicit engine type")
    func explicitEngineType() {
        let dto = MeetingSummaryDTO(
            summary: "test",
            keyPoints: ["a"],
            actionItems: ["b"],
            engineType: .extractive
        )

        #expect(dto.engineType == .extractive)
    }

    @Test("Pipeline end-to-end with SummarizationEngine")
    @MainActor
    func pipelineWithEngine() async throws {
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)

        let pipeline = MeetingPipeline(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: SummarizationEngine(),
            repository: repository
        )

        let dummyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-engine.m4a")
        FileManager.default.createFile(atPath: dummyURL.path, contents: Data())

        let meeting = try await pipeline.process(
            audioURL: dummyURL,
            duration: 30.0,
            language: "en"
        )

        #expect(!meeting.summary.isEmpty)
        #expect(meeting.summaryEngine == SummarizationEngineType.extractive.rawValue)
        #expect(!meeting.actionItemCompletions.isEmpty || meeting.actionItems.isEmpty)

        try? FileManager.default.removeItem(at: dummyURL)
    }
}
