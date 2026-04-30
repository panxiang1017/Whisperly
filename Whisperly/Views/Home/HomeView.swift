import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(StoreManager.self) private var store
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]
    @State private var showRecording = false
    @State private var selectedMeeting: Meeting?
    @State private var showPaywall = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
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
                } else {
                    meetingList
                }
            }
            .navigationTitle(String(localized: "Whisperly"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    recordButton
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(String(localized: "Settings"), systemImage: "gearshape")
                    }
                }
                #else
                ToolbarItem {
                    NavigationLink {
                        SettingsView()
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
                MeetingDetailView(meeting: meeting)
            }
        }
    }

    // MARK: - Subviews

    private var meetingList: some View {
        List {
            ForEach(meetings) { meeting in
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

    private func deleteMeetings(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let meeting = meetings[index]
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
