import Testing
import Foundation
import SwiftData
@testable import Whisperly

@Suite("Meeting Repository Tests")
struct MeetingRepositoryTests {

    @Test("Repository CRUD")
    @MainActor
    func repositoryCRUD() async throws {
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)

        // Create
        let segments = [
            TranscriptSegmentDTO(startTime: 0, endTime: 5, text: "Hello world"),
            TranscriptSegmentDTO(startTime: 5, endTime: 10, text: "Testing one two three"),
        ]
        let speakers = [
            SpeakerDTO(label: "Speaker 1", colorHex: "007AFF"),
        ]
        let summary = MeetingSummaryDTO(
            summary: "Test summary",
            keyPoints: ["Point 1", "Point 2"],
            actionItems: ["Action 1"]
        )

        let meeting = try await repository.createMeeting(
            title: "Test Meeting",
            duration: 42.0,
            audioURL: nil,
            segments: segments,
            speakers: speakers,
            summary: summary,
            language: "en"
        )

        #expect(meeting.title == "Test Meeting")
        #expect(meeting.duration == 42.0)
        #expect(meeting.summary == "Test summary")
        #expect(meeting.keyPoints.count == 2)
        #expect(meeting.actionItems.count == 1)
        #expect(meeting.segments.count == 2)
        #expect(meeting.speakers.count == 1)

        // Read all
        let allMeetings = try await repository.fetchAll()
        #expect(allMeetings.count == 1)

        // Read by ID
        let fetched = try await repository.fetch(id: meeting.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Test Meeting")

        // Update
        try await repository.updateTitle(meeting, title: "Updated Title")
        let updated = try await repository.fetch(id: meeting.id)
        #expect(updated?.title == "Updated Title")

        // Delete
        try await repository.delete(meeting)
        let afterDelete = try await repository.fetchAll()
        #expect(afterDelete.isEmpty)
    }
}
