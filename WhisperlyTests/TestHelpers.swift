import Foundation
import SwiftData
@testable import Whisperly

enum TestHelpers {
    @MainActor
    static func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Meeting.self,
            TranscriptSegment.self,
            Speaker.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
