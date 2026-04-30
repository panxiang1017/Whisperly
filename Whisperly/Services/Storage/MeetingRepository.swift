import Foundation
import SwiftData

// TODO: Remove @MainActor when background ModelContext + DTO return types are implemented.
@MainActor
protocol MeetingRepositoryProtocol {
    func createMeeting(
        title: String,
        duration: TimeInterval,
        audioURL: URL?,
        segments: [TranscriptSegmentDTO],
        speakers: [SpeakerDTO],
        summary: MeetingSummaryDTO,
        language: String
    ) async throws -> Meeting

    func fetchAll() async throws -> [Meeting]
    func fetch(id: UUID) async throws -> Meeting?
    func delete(_ meeting: Meeting) async throws
    func updateTitle(_ meeting: Meeting, title: String) async throws
}

@MainActor
final class SwiftDataMeetingRepository: MeetingRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createMeeting(
        title: String,
        duration: TimeInterval,
        audioURL: URL?,
        segments: [TranscriptSegmentDTO],
        speakers: [SpeakerDTO],
        summary: MeetingSummaryDTO,
        language: String
    ) async throws -> Meeting {
        let meeting = Meeting(
            title: title,
            duration: duration,
            audioFileURL: audioURL,
            summary: summary.summary,
            keyPoints: summary.keyPoints,
            actionItems: summary.actionItems,
            language: language
        )

        let speakerModels = speakers.map { dto in
            Speaker(id: dto.id, label: dto.label, colorHex: dto.colorHex, meeting: meeting)
        }

        let segmentModels = segments.map { dto in
            TranscriptSegment(
                id: dto.id,
                startTime: dto.startTime,
                endTime: dto.endTime,
                text: dto.text,
                speakerID: dto.speakerID,
                meeting: meeting
            )
        }

        meeting.speakers = speakerModels
        meeting.segments = segmentModels

        modelContext.insert(meeting)
        try modelContext.save()

        return meeting
    }

    func fetchAll() async throws -> [Meeting] {
        let descriptor = FetchDescriptor<Meeting>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) async throws -> Meeting? {
        let descriptor = FetchDescriptor<Meeting>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func delete(_ meeting: Meeting) async throws {
        modelContext.delete(meeting)
        try modelContext.save()
    }

    func updateTitle(_ meeting: Meeting, title: String) async throws {
        meeting.title = title
        try modelContext.save()
    }
}
