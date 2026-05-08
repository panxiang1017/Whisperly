import Testing
import Foundation
@testable import Whisperly

@Suite("Model Manager Tests")
struct ModelManagerTests {

    @Test("Test initializer sets MLX state correctly")
    @MainActor
    func testInitializer() {
        let ready = ModelManager(mlxState: .ready)
        #expect(ready.mlxModelState == .ready)

        let notReady = ModelManager(mlxState: .notDownloaded)
        #expect(notReady.mlxModelState == .notDownloaded)
    }
}
