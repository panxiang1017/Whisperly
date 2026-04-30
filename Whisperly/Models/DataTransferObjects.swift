import Foundation

struct TranscriptSegmentDTO: Sendable, Equatable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let speakerID: UUID?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        speakerID: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.speakerID = speakerID
    }
}

struct SpeakerDTO: Sendable, Equatable {
    let id: UUID
    let label: String
    let colorHex: String

    init(
        id: UUID = UUID(),
        label: String,
        colorHex: String = "007AFF"
    ) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
    }
}

struct MeetingSummaryDTO: Sendable, Equatable {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}
