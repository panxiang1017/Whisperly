import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    var exportService: any ExportServiceProtocol = ExportService()
    var summarizationService: (any SummarizationServiceProtocol)?
    var repository: (any MeetingRepositoryProtocol)?
    @State private var selectedTab: DetailTab = .transcript
    @State private var isRegenerating = false
    @State private var regenerateError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab picker with sliding indicator
            DetailTabPicker(selectedTab: $selectedTab)
                .padding(.horizontal, AppTheme.paddingM)
                .padding(.vertical, AppTheme.paddingS)

            switch selectedTab {
            case .transcript:
                transcriptView
            case .summary:
                summaryView
            case .speakers:
                speakersView
            }
        }
        .background(AppTheme.backgroundGradient)
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
            LazyVStack(alignment: .leading, spacing: AppTheme.paddingM) {
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
                            .padding(AppTheme.paddingM)
                            .premiumGlassCard(cornerRadius: AppTheme.cornerRadiusS)
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
                // Engine badge + regenerate
                HStack {
                    EngineBadge(engine: meeting.summaryEngine)
                    Spacer()
                    if summarizationService != nil && repository != nil {
                        Button {
                            Task { await regenerateSummary() }
                        } label: {
                            if isRegenerating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(String(localized: "Regenerate"), systemImage: "arrow.clockwise")
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.accentTeal)
                            }
                        }
                        .disabled(isRegenerating)
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppTheme.paddingS)
                        .padding(.vertical, AppTheme.paddingXS)
                        .background(
                            Capsule()
                                .fill(AppTheme.accentTeal.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppTheme.accentTeal.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    }
                }

                if let error = regenerateError {
                    Text(error)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.destructive)
                }

                if !meeting.summary.isEmpty {
                    SummarySection(
                        title: String(localized: "Summary"),
                        systemImage: "doc.text"
                    ) {
                        Text(meeting.summary)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(AppTheme.paddingM)
                    .premiumGlassCard()
                }

                if !meeting.keyPoints.isEmpty {
                    SummarySection(
                        title: String(localized: "Key Points"),
                        systemImage: "list.bullet"
                    ) {
                        ForEach(meeting.keyPoints, id: \.self) { point in
                            Label {
                                Text(point)
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(AppTheme.primaryText)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accentTeal)
                            }
                        }
                    }
                    .padding(AppTheme.paddingM)
                    .premiumGlassCard()
                }

                if !meeting.actionItems.isEmpty {
                    SummarySection(
                        title: String(localized: "Action Items"),
                        systemImage: "checklist"
                    ) {
                        ForEach(Array(meeting.actionItems.enumerated()), id: \.offset) { index, item in
                            ActionItemRow(
                                item: item,
                                isCompleted: index < meeting.actionItemCompletions.count
                                    ? meeting.actionItemCompletions[index]
                                    : false,
                                onToggle: {
                                    Task {
                                        try? await repository?.toggleActionItem(meeting, index: index)
                                    }
                                }
                            )
                        }
                    }
                    .padding(AppTheme.paddingM)
                    .premiumGlassCard()
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
                    let totalSegments = max(1, meeting.segments.count)
                    ForEach(meeting.speakers, id: \.id) { speaker in
                        let segmentCount = meeting.segments.filter { $0.speakerID == speaker.id }.count
                        let ratio = Double(segmentCount) / Double(totalSegments)

                        HStack(spacing: AppTheme.paddingM) {
                            // Avatar circle (larger, with glow border)
                            ZStack {
                                Circle()
                                    .fill(Color(hex: speaker.colorHex).opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .strokeBorder(Color(hex: speaker.colorHex).opacity(0.4), lineWidth: 1)
                                    .frame(width: 44, height: 44)
                                Text(String(speaker.label.prefix(1)))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(speaker.label)
                                        .font(AppTheme.headlineFont)
                                        .foregroundStyle(AppTheme.primaryText)

                                    Spacer()

                                    Text(String(localized: "\(segmentCount) segments"))
                                        .font(AppTheme.captionFont)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                // Speaking ratio bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(AppTheme.divider)
                                            .frame(height: 3)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(AppTheme.accentTeal)
                                            .frame(width: max(4, geo.size.width * ratio), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                        .padding(AppTheme.paddingM)
                        .premiumGlassCard()
                    }
                }
            }
            .padding(AppTheme.paddingM)
        }
    }

    // MARK: - Regenerate Summary

    private func regenerateSummary() async {
        guard let service = summarizationService, let repo = repository else { return }
        isRegenerating = true
        regenerateError = nil

        do {
            let segmentDTOs = meeting.segments
                .sorted { $0.startTime < $1.startTime }
                .map { TranscriptSegmentDTO(id: $0.id, startTime: $0.startTime, endTime: $0.endTime, text: $0.text, speakerID: $0.speakerID) }

            let newSummary = try await service.summarize(transcript: segmentDTOs)
            try await repo.updateSummary(meeting, summary: newSummary)
        } catch {
            regenerateError = error.localizedDescription
        }

        isRegenerating = false
    }

    // MARK: - Export

    private var exportedText: String {
        let exporter = exportService
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

// MARK: - Custom Tab Picker with Sliding Indicator

struct DetailTabPicker: View {
    @Binding var selectedTab: DetailTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.label)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(selectedTab == tab ? AppTheme.primaryText : AppTheme.inactiveText)
                        .padding(.horizontal, AppTheme.paddingM)
                        .padding(.vertical, AppTheme.paddingS)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(AppTheme.accentTeal.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppTheme.accentTeal.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL, style: .continuous)
                .fill(AppTheme.appBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL, style: .continuous)
                        .strokeBorder(AppTheme.divider, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Action Item Row

struct ActionItemRow: View {
    let item: String
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: AppTheme.paddingS) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? AppTheme.accentTeal : AppTheme.inactiveText)
                    .font(.title3)

                Text(item)
                    .font(AppTheme.bodyFont)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? AppTheme.secondaryText : AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Engine Badge

struct EngineBadge: View {
    let engine: String

    var body: some View {
        HStack(spacing: AppTheme.paddingXS) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(displayName)
                .font(AppTheme.captionFont)
        }
        .padding(.horizontal, AppTheme.paddingS)
        .padding(.vertical, AppTheme.paddingXS)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(badgeColor.opacity(0.2), lineWidth: 1)
                )
        )
        .foregroundStyle(badgeColor)
    }

    private var displayName: String {
        switch engine {
        case SummarizationEngineType.appleFoundationModels.rawValue:
            String(localized: "Apple AI")
        case SummarizationEngineType.mlx.rawValue:
            String(localized: "MLX Qwen")
        case SummarizationEngineType.extractive.rawValue:
            String(localized: "Basic Summary")
        default:
            String(localized: "Mock")
        }
    }

    private var iconName: String {
        switch engine {
        case SummarizationEngineType.appleFoundationModels.rawValue:
            "apple.logo"
        case SummarizationEngineType.mlx.rawValue:
            "cpu"
        case SummarizationEngineType.extractive.rawValue:
            "text.magnifyingglass"
        default:
            "sparkles"
        }
    }

    private var badgeColor: Color {
        switch engine {
        case SummarizationEngineType.appleFoundationModels.rawValue:
            AppTheme.accentTeal
        case SummarizationEngineType.mlx.rawValue:
            AppTheme.accentPurple
        case SummarizationEngineType.extractive.rawValue:
            .orange
        default:
            AppTheme.secondaryText
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
                    // Speaker capsule badge
                    Text(speaker.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(speakerColor(for: speaker))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(speakerColor(for: speaker).opacity(0.12))
                        )
                }

                Spacer()

                Text(formatTimestamp(segment.startTime))
                    .font(AppTheme.timestampFont)
                    .foregroundStyle(AppTheme.inactiveText)
            }

            Text(segment.text)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func speakerColor(for speaker: Speaker) -> Color {
        let index = speakers.firstIndex(where: { $0.id == speaker.id }) ?? 0
        return index % 2 == 0 ? AppTheme.speakerTeal : AppTheme.speakerPurple
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
                .foregroundStyle(AppTheme.primaryText)

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
