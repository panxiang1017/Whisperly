import SwiftUI
import SwiftData

@main
struct WhisperlyApp: App {
    private let modelContainer: ModelContainer
    @State private var dependencies: AppDependencies

    init() {
        let schema = Schema([
            Meeting.self,
            TranscriptSegment.self,
            Speaker.self,
        ])

        // Configure CloudKit sync based on user preference (default OFF).
        let configuration: ModelConfiguration
        if CloudKitSyncCoordinator.isSyncEnabled {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.ai.dxy.Whisperly")
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)
            self._dependencies = State(initialValue: AppDependencies(repository: repository))
            print("[Whisperly] ModelContainer created successfully")
        } catch {
            print("[Whisperly] ModelContainer FAILED: \(error)")
            // Fallback: create without CloudKit
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            let container = try! ModelContainer(for: schema, configurations: [fallback])
            self.modelContainer = container
            let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)
            self._dependencies = State(initialValue: AppDependencies(repository: repository))
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView(dependencies: dependencies)
                .environment(dependencies.storeManager)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 500)
                .background(AppTheme.backgroundGradient)
        }
        #if os(macOS)
        // .windowStyle(.hiddenTitleBar) // Removed: causes window not to appear on macOS 26
        #endif
    }
}
