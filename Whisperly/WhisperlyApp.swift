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
            AppSettings.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)
            self._dependencies = State(initialValue: AppDependencies(repository: repository))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView(dependencies: dependencies)
                .environment(dependencies.storeManager)
                .modelContainer(modelContainer)
        }
    }
}
