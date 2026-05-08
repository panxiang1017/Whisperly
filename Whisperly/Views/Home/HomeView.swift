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
                        recordButton
                    }
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView(modelManager: dependencies.modelManager)
                        } label: {
                            Label(String(localized: "Settings"), systemImage: "gearshape")
                        }
                    }
                    #else
                    ToolbarItem {
                        NavigationLink {
                            SettingsView(modelManager: dependencies.modelManager)
                        } label: {
                            Label(String(localized: "Settings"), systemImage: "gearshape")
                        }
                    }
                    #endif
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
                .background(AppTheme.contentBackground)
            } else {
                PrivacyEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.contentBackground)
            }
        }
        .background(AppTheme.sidebarBackground)
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
                PrivacyEmptyStateView()
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
    }

    // MARK: - Subviews

    private var meetingList: some View {
        List(selection: $selectedMeeting) {
            ForEach(filteredMeetings) { meeting in
                MeetingRow(meeting: meeting)
                    .tag(meeting)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS, style: .continuous)
                            .fill(selectedMeeting?.id == meeting.id
                                  ? AppTheme.accentTeal.opacity(0.12)
                                  : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS, style: .continuous)
                                    .strokeBorder(
                                        selectedMeeting?.id == meeting.id
                                        ? AppTheme.accentTeal.opacity(0.3)
                                        : Color.clear,
                                        lineWidth: 1
                                    )
                            )
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
                    .strokeBorder(AppTheme.recording.opacity(0.4), lineWidth: 1)
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

            Text(String(localized: "Your meetings stay on this device"))
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.inactiveText)
                .padding(.top, AppTheme.paddingXS)
        }
        .padding(AppTheme.paddingXL)
    }
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
            Text(meeting.title.isEmpty ? String(localized: "Untitled Meeting") : meeting.title)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            HStack(spacing: AppTheme.paddingS) {
                Label(formattedDate, systemImage: "calendar")
                Label(formattedDuration, systemImage: "clock")

                if !meeting.speakers.isEmpty {
                    Label("\(meeting.speakers.count)", systemImage: "person.2")
                }
            }
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.secondaryText)

            if !meeting.summary.isEmpty {
                Text(meeting.summary)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
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
