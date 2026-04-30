import Testing
import Foundation
import SwiftData
@testable import Whisperly

@Suite("Pipeline Tests")
struct PipelineTests {

    @Test("Pipeline produces meeting end-to-end with mocks")
    @MainActor
    func pipelineEndToEnd() async throws {
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)

        let pipeline = MeetingPipeline(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: MockSummarizationService(),
            repository: repository
        )

        var stages: [PipelineStage] = []
        pipeline.onStageChanged = { stage in
            stages.append(stage)
        }

        let dummyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio.m4a")
        FileManager.default.createFile(atPath: dummyURL.path, contents: Data())

        let meeting = try await pipeline.process(
            audioURL: dummyURL,
            duration: 42.0,
            language: "en"
        )

        // Verify meeting was created with all data
        #expect(!meeting.title.isEmpty)
        #expect(meeting.duration == 42.0)
        #expect(!meeting.summary.isEmpty)
        #expect(!meeting.keyPoints.isEmpty)
        #expect(!meeting.actionItems.isEmpty)
        #expect(!meeting.segments.isEmpty)
        #expect(!meeting.speakers.isEmpty)
        #expect(meeting.language == "en")

        // Verify all pipeline stages were hit
        #expect(stages.contains(.transcribing))
        #expect(stages.contains(.diarizing))
        #expect(stages.contains(.summarizing))
        #expect(stages.contains(.saving))
        #expect(stages.contains(.completed))

        // Verify persisted in repository
        let allMeetings = try await repository.fetchAll()
        #expect(allMeetings.count == 1)
        #expect(allMeetings.first?.id == meeting.id)

        // Cleanup
        try? FileManager.default.removeItem(at: dummyURL)
    }

    @Test("Pipeline stages fire in correct order")
    @MainActor
    func pipelineStagesOrder() async throws {
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)

        let pipeline = MeetingPipeline(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: MockSummarizationService(),
            repository: repository
        )

        var stages: [PipelineStage] = []
        pipeline.onStageChanged = { stage in
            stages.append(stage)
        }

        let dummyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-2.m4a")
        FileManager.default.createFile(atPath: dummyURL.path, contents: Data())

        _ = try await pipeline.process(audioURL: dummyURL, duration: 10.0)

        #expect(stages.count == 5)
        #expect(stages[0] == .transcribing)
        #expect(stages[1] == .diarizing)
        #expect(stages[2] == .summarizing)
        #expect(stages[3] == .saving)
        #expect(stages[4] == .completed)

        try? FileManager.default.removeItem(at: dummyURL)
    }
}
