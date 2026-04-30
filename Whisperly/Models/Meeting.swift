import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var duration: TimeInterval = 0
    var audioFileURL: URL?
    var summary: String = ""
    var keyPoints: [String] = []
    var actionItems: [String] = []
    var language: String = "en"
    var summaryEngine: String = "mock"
    var actionItemCompletions: [Bool] = []

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.meeting)
    var segments: [TranscriptSegment] = []

    @Relationship(deleteRule: .cascade, inverse: \Speaker.meeting)
    var speakers: [Speaker] = []

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileURL: URL? = nil,
        summary: String = "",
        keyPoints: [String] = [],
        actionItems: [String] = [],
        language: String = "en",
        summaryEngine: String = "mock",
        actionItemCompletions: [Bool] = [],
        segments: [TranscriptSegment] = [],
        speakers: [Speaker] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.summary = summary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.language = language
        self.summaryEngine = summaryEngine
        self.actionItemCompletions = actionItemCompletions
        self.segments = segments
        self.speakers = speakers
    }
}
