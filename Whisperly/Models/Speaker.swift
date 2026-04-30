import Foundation
import SwiftData

@Model
final class Speaker {
    var id: UUID
    var label: String
    var colorHex: String
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        label: String = "",
        colorHex: String = "007AFF",
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.meeting = meeting
    }
}
