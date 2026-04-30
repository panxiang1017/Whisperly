import Testing
import Foundation
@testable import Whisperly

@Suite("Model Manager Tests")
struct ModelManagerTests {

    @Test("Recommended model is based on device memory")
    func recommendedModel() {
        let model = ModelManager.recommendedModelName()
        // On any CI / development machine, memory >= 6 GB → large-v3-turbo
        // On a 4 GB device → small
        let validModels = ["large-v3-turbo", "small"]
        #expect(validModels.contains(model))
    }

    @Test("Estimated model size returns known values")
    func estimatedSize() {
        #expect(ModelManager.estimatedModelSize(for: "large-v3-turbo") == "~626 MB")
        #expect(ModelManager.estimatedModelSize(for: "small") == "~244 MB")
        #expect(ModelManager.estimatedModelSize(for: "base") == "~74 MB")
    }

    @Test("Test initializer sets state correctly")
    @MainActor
    func testInitializer() {
        let manager = ModelManager(modelName: "test-model", state: .ready)
        #expect(manager.whisperModelName == "test-model")
        #expect(manager.isReady)

        let notReady = ModelManager(modelName: "test-model", state: .notDownloaded)
        #expect(!notReady.isReady)
    }
}
