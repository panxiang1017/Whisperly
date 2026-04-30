import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    @State private var selectedTab: DetailTab = .transcript

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker(String(localized: "View"), selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.paddingM)
            .padding(.vertical, AppTheme.paddingS)

            // Tab content
            switch selectedTab {
            case .transcript:
                transcriptView
            case .summary:
                summaryView
            case .speakers:
                speakersView
            }
        }
        .navigationTitle(meeting.title.isEmpty ? String(localized: "Meeting Details") : meeting.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: exportedText,
                    subject: Text(meeting.title),
                    message: Text(String(localized: "Meeting notes from Whisperly"))
                )
            }
        }
    }

    // MARK: - Transcript Tab

    private var transcriptView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.paddingS) {
                if meeting.segments.isEmpty {
                    EmptyStateView(
                        systemImage: "text.quote",
                        title: String(localized: "No transcript"),
                        message: String(localized: "The transcript will appear here after processing.")
                    )
                } else {
                    let sortedSegments = meeting.segments.sorted { $0.startTime < $1.startTime }
                    ForEach(sortedSegments, id: \.id) { segment in
                        SegmentRow(segment: segment, speakers: meeting.speakers)
                    }
                }
            }
            .padding(AppTheme.paddingM)
        }
    }

    // MARK: - Summary Tab

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.paddingL) {
                if !meeting.summary.isEmpty {
                    SummarySection(
                        title: String(localized: "Summary"),
                        systemImage: "doc.text"
                    ) {
                        Text(meeting.summary)
                            .font(AppTheme.bodyFont)
                    }
                }

                if !meeting.keyPoints.isEmpty {
                    SummarySection(
                        title: String(localized: "Key Points"),
                        systemImage: "list.bullet"
                    ) {
                        ForEach(meeting.keyPoints, id: \.self) { point in
                            Label(point, systemImage: "checkmark.circle.fill")
                                .font(AppTheme.bodyFont)
                        }
                    }
                }

                if !meeting.actionItems.isEmpty {
                    SummarySection(
                        title: String(localized: "Action Items"),
                        systemImage: "checklist"
                    ) {
                        ForEach(meeting.actionItems, id: \.self) { item in
                            Label(item, systemImage: "circle")
                                .font(AppTheme.bodyFont)
                        }
                    }
                }

                if meeting.summary.isEmpty && meeting.keyPoints.isEmpty && meeting.actionItems.isEmpty {
                    EmptyStateView(
                        systemImage: "sparkles",
                        title: String(localized: "No summary"),
                        message: String(localized: "The AI summary will appear here after processing.")
                    )
                }
            }
            .padding(AppTheme.paddingM)
        }
    }

    // MARK: - Speakers Tab

    private var speakersView: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.paddingS) {
                if meeting.speakers.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: String(localized: "No speakers identified"),
                        message: String(localized: "Speaker information will appear here after processing.")
                    )
                } else {
                    ForEach(meeting.speakers, id: \.id) { speaker in
                        HStack(spacing: AppTheme.paddingM) {
                            Circle()
                                .fill(Color(hex: speaker.colorHex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Text(String(speaker.label.prefix(1)))
                                        .font(AppTheme.captionFont)
                                        .foregroundStyle(.white)
                                }

                            Text(speaker.label)
                                .font(AppTheme.headlineFont)

                            Spacer()

                            let segmentCount = meeting.segments.filter { $0.speakerID == speaker.id }.count
                            Text(String(localized: "\(segmentCount) segments"))
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(AppTheme.paddingM)
                        .cardStyle()
                    }
                }
            }
            .padding(AppTheme.paddingM)
        }
    }

    // MARK: - Export

    private var exportedText: String {
        let exporter = ExportService()
        let exportable = ExportableMeeting(
            title: meeting.title,
            createdAt: meeting.createdAt,
            duration: meeting.duration,
            summary: meeting.summary,
            keyPoints: meeting.keyPoints,
            actionItems: meeting.actionItems,
            segments: meeting.segments.sorted { $0.startTime < $1.startTime }.map {
                ExportableSegment(startTime: $0.startTime, endTime: $0.endTime, text: $0.text, speakerID: $0.speakerID)
            },
            speakers: Dictionary(
                uniqueKeysWithValues: meeting.speakers.map { ($0.id, $0.label) }
            )
        )
        return (try? exporter.export(meeting: exportable, format: .plainText)) ?? ""
    }
}

// MARK: - Detail Tab

enum DetailTab: String, CaseIterable, Identifiable {
    case transcript
    case summary
    case speakers

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transcript: String(localized: "Transcript")
        case .summary: String(localized: "Summary")
        case .speakers: String(localized: "Speakers")
        }
    }
}

// MARK: - Supporting Views

struct SegmentRow: View {
    let segment: TranscriptSegment
    let speakers: [Speaker]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
            HStack {
                if let speakerID = segment.speakerID,
                   let speaker = speakers.first(where: { $0.id == speakerID })
                {
                    Text(speaker.label)
                        .font(AppTheme.captionFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: speaker.colorHex))
                }

                Text(formatTimestamp(segment.startTime))
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text(segment.text)
                .font(AppTheme.bodyFont)
        }
        .padding(.vertical, AppTheme.paddingXS)
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingS) {
            Label(title, systemImage: systemImage)
                .font(AppTheme.titleFont)

            content
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
