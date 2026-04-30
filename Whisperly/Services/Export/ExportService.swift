import Foundation

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case plainText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: String(localized: "Markdown")
        case .plainText: String(localized: "Plain Text")
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        }
    }
}

protocol ExportServiceProtocol: Sendable {
    func export(meeting: ExportableMeeting, format: ExportFormat) throws -> String
}

/// Value type for passing meeting data to the export service without SwiftData dependency.
struct ExportableMeeting: Sendable {
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
    let segments: [ExportableSegment]
    let speakers: [UUID: String]
}

struct ExportableSegment: Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let speakerID: UUID?
}

final class ExportService: ExportServiceProtocol, Sendable {
    func export(meeting: ExportableMeeting, format: ExportFormat) throws -> String {
        switch format {
        case .markdown:
            return exportMarkdown(meeting)
        case .plainText:
            return exportPlainText(meeting)
        }
    }

    private func exportMarkdown(_ meeting: ExportableMeeting) -> String {
        var lines: [String] = []
        lines.append("# \(meeting.title)")
        lines.append("")

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        lines.append("**\(String(localized: "Date")):** \(formatter.string(from: meeting.createdAt))")
        lines.append("**\(String(localized: "Duration")):** \(formattedDuration(meeting.duration))")
        lines.append("")

        if !meeting.summary.isEmpty {
            lines.append("## \(String(localized: "Summary"))")
            lines.append("")
            lines.append(meeting.summary)
            lines.append("")
        }

        if !meeting.keyPoints.isEmpty {
            lines.append("## \(String(localized: "Key Points"))")
            lines.append("")
            for point in meeting.keyPoints {
                lines.append("- \(point)")
            }
            lines.append("")
        }

        if !meeting.actionItems.isEmpty {
            lines.append("## \(String(localized: "Action Items"))")
            lines.append("")
            for item in meeting.actionItems {
                lines.append("- [ ] \(item)")
            }
            lines.append("")
        }

        if !meeting.segments.isEmpty {
            lines.append("## \(String(localized: "Transcript"))")
            lines.append("")
            for segment in meeting.segments {
                let speaker = segment.speakerID.flatMap { meeting.speakers[$0] } ?? String(localized: "Unknown")
                let timestamp = formatTimestamp(segment.startTime)
                lines.append("**[\(timestamp)] \(speaker):** \(segment.text)")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func exportPlainText(_ meeting: ExportableMeeting) -> String {
        var lines: [String] = []
        lines.append(meeting.title)
        lines.append(String(repeating: "=", count: meeting.title.count))
        lines.append("")

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        lines.append("\(String(localized: "Date")): \(formatter.string(from: meeting.createdAt))")
        lines.append("\(String(localized: "Duration")): \(formattedDuration(meeting.duration))")
        lines.append("")

        if !meeting.summary.isEmpty {
            lines.append(String(localized: "Summary"))
            lines.append(String(repeating: "-", count: 7))
            lines.append(meeting.summary)
            lines.append("")
        }

        if !meeting.segments.isEmpty {
            lines.append(String(localized: "Transcript"))
            lines.append(String(repeating: "-", count: 10))
            for segment in meeting.segments {
                let speaker = segment.speakerID.flatMap { meeting.speakers[$0] } ?? String(localized: "Unknown")
                let timestamp = formatTimestamp(segment.startTime)
                lines.append("[\(timestamp)] \(speaker): \(segment.text)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
