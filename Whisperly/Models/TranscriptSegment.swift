import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var id: UUID = UUID()
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var text: String = ""
    var speakerID: UUID?
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 0,
        text: String = "",
        speakerID: UUID? = nil,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.speakerID = speakerID
        self.meeting = meeting
    }
}
