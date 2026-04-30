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
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    EmptyStateView(
                        systemImage: "waveform",
                        title: String(localized: "No meetings yet"),
                        message: String(localized: "Tap the record button to start your first meeting.")
                    )
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
            .navigationDestination(item: $selectedMeeting) { meeting in
                MeetingDetailView(
                    meeting: meeting,
                    exportService: dependencies.exportService,
                    summarizationService: dependencies.summarizationService,
                    repository: dependencies.repository
                )
            }
        }
    }

    // MARK: - Subviews

    private var meetingList: some View {
        List {
            ForEach(filteredMeetings) { meeting in
                Button {
                    selectedMeeting = meeting
                } label: {
                    MeetingRow(meeting: meeting)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteMeetings)
        }
        .listStyle(.plain)
    }

    private var recordButton: some View {
        Button {
            showRecording = true
        } label: {
            Label(String(localized: "Record"), systemImage: "record.circle")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.recording)
        }
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

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
            Text(meeting.title.isEmpty ? String(localized: "Untitled Meeting") : meeting.title)
                .font(AppTheme.headlineFont)
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
