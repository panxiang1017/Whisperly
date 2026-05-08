import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(StoreManager.self) private var store
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]
    @State private var showRecording = false
    @State private var selectedMeeting: Meeting?
    @State private var showPaywall = false
    @State private var searchText = ""
    @State private var searchResultIDs: Set<UUID>?
    @State private var searchTask: Task<Void, Never>?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Meetings filtered by the current FTS5 search query.
    private var filteredMeetings: [Meeting] {
        guard let ids = searchResultIDs else { return meetings }
        return meetings.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle(String(localized: "Whisperly"))
                .searchable(
                    text: $searchText,
                    prompt: String(localized: "Search meetings")
                )
                .onChange(of: searchText) { _, newValue in
                    debounceSearch(newValue)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: AppTheme.paddingS) {
                            recordButton

                            NavigationLink {
                                SettingsView(modelManager: dependencies.modelManager)
                            } label: {
                                Label(String(localized: "Settings"), systemImage: "gearshape")
                                    .font(AppTheme.headlineFont)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
        } detail: {
            if let meeting = selectedMeeting {
                MeetingDetailView(
                    meeting: meeting,
                    exportService: dependencies.exportService,
                    summarizationService: dependencies.summarizationService,
                    repository: dependencies.repository
                )
                .id(meeting.id)
                .background(AppTheme.backgroundGradient)
            } else {
                PrivacyEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.backgroundGradient)
            }
        }
        .background(AppTheme.backgroundGradient)
        .sheet(isPresented: $showRecording) {
            NavigationStack {
                RecordingView(
                    viewModel: dependencies.makeRecordingViewModel()
                )
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 600)
            #endif
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        Group {
            if meetings.isEmpty {
                VStack(spacing: AppTheme.paddingM) {
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(AppTheme.accentTeal.opacity(0.4))
                    Text(String(localized: "No meetings yet"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(String(localized: "Tap Record to start"))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.inactiveText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if !searchText.isEmpty && filteredMeetings.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: String(localized: "No results"),
                    message: String(localized: "No meetings matched your search.")
                )
            } else {
                meetingList
            }
        }
        .background(AppTheme.backgroundGradient)
    }

    // MARK: - Subviews

    private var meetingList: some View {
        List(selection: $selectedMeeting) {
            ForEach(filteredMeetings) { meeting in
                MeetingRow(meeting: meeting, isSelected: selectedMeeting?.id == meeting.id)
                    .tag(meeting)
                    .listRowBackground(
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS, style: .continuous)
                                .fill(selectedMeeting?.id == meeting.id
                                      ? AppTheme.accentTeal.opacity(0.08)
                                      : Color.clear)
                            if selectedMeeting?.id == meeting.id {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(AppTheme.accentTeal)
                                    .frame(width: 2)
                                    .padding(.vertical, 4)
                            }
                        }
                    )
            }
            .onDelete(perform: deleteMeetings)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var recordButton: some View {
        Button {
            showRecording = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "record.circle")
                Text(String(localized: "Record"))
            }
            .font(AppTheme.headlineFont)
            .foregroundStyle(AppTheme.recording)
            .padding(.horizontal, AppTheme.paddingS)
            .padding(.vertical, AppTheme.paddingXS)
            .background(
                Capsule()
                    .fill(AppTheme.recording.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.recording.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResultIDs = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            if let ids = try? await dependencies.searchService.search(query: trimmed) {
                searchResultIDs = Set(ids)
            }
        }
    }

    // MARK: - Actions

    private func deleteMeetings(at offsets: IndexSet) {
        Task {
            let meetingsToDelete = offsets.map { filteredMeetings[$0] }
            for meeting in meetingsToDelete {
                try? await dependencies.repository.delete(meeting)
            }
        }
    }
}

// MARK: - Privacy Empty State

struct PrivacyEmptyStateView: View {
    @State private var glowOpacity: Double = 0.4

    var body: some View {
        VStack(spacing: AppTheme.paddingL) {
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accentTeal.opacity(glowOpacity * 0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Shield + waveform
                ZStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(AppTheme.tealPurpleGradient)

                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppTheme.accentTeal)
                        .offset(x: 2, y: 2)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.8
                }
            }

            Text(String(localized: "No meetings yet"))
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.primaryText)

            Text(String(localized: "Tap the record button to start your first meeting."))
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            // Feature badges
            HStack(spacing: AppTheme.paddingL) {
                PrivacyFeatureBadge(icon: "shield.checkmark", label: "On-device")
                PrivacyFeatureBadge(icon: "lock.fill", label: "Encrypted")
                PrivacyFeatureBadge(icon: "bolt.fill", label: "Real-time")
            }
            .padding(.top, AppTheme.paddingS)

            Text(String(localized: "Your meetings stay on this device"))
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.inactiveText)
        }
        .padding(AppTheme.paddingXL)
    }
}

// MARK: - Privacy Feature Badge

struct PrivacyFeatureBadge: View {
    let icon: String
    let label: String
    @State private var glow: Double = 0.3

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentTeal.opacity(glow * 0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.accentTeal)
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glow = 1.0
            }
        }
    }
}

// MARK: - Capsule Badge

struct CapsuleBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingXS + 2) {
            // Title with privacy badge
            HStack(spacing: 6) {
                if meeting.createdAt.timeIntervalSinceNow > -86400 {
                    Image(systemName: "shield.checkmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.accentTeal.opacity(0.7))
                }
                Text(meeting.title.isEmpty ? String(localized: "Untitled Meeting") : meeting.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }

            // Meta badges
            HStack(spacing: 6) {
                CapsuleBadge(icon: "calendar", text: formattedDate)
                CapsuleBadge(icon: "clock", text: formattedDuration)

                if !meeting.speakers.isEmpty {
                    CapsuleBadge(icon: "person.2", text: "\(meeting.speakers.count)")
                }
            }

            // Summary preview
            if !meeting.summary.isEmpty {
                Text(meeting.summary)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            // Bottom separator + segment count
            HStack(spacing: AppTheme.paddingS) {
                Rectangle()
                    .fill(AppTheme.divider)
                    .frame(height: 0.5)
                Text(String(localized: "\(meeting.segments.count) segments"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.inactiveText)
                    .fixedSize()
            }
        }
        .padding(.vertical, AppTheme.paddingXS)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var formattedDate: String {
        meeting.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var formattedDuration: String {
        let minutes = Int(meeting.duration) / 60
        let seconds = Int(meeting.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
