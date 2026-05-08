import Foundation
import SwiftUI

/// Manages on-device model downloads for MLX summarization.
@MainActor
@Observable
final class ModelManager {
    enum ModelState: Equatable, Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    private(set) var mlxModelState: ModelState = .notDownloaded
    let mlxModelName: String = "Qwen2.5-3B-Instruct-4bit"

    private let fileManager = FileManager.default

    // MARK: - Lifecycle

    init() {
        mlxModelState = Self.isMLXModelDownloaded() ? .ready : .notDownloaded
    }

    /// Test-only initializer that skips model detection.
    init(mlxState: ModelState) {
        self.mlxModelState = mlxState
    }

    // MARK: - MLX Model Management

    nonisolated static var mlxModelsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whisperly/MLXModels", isDirectory: true)
    }

    nonisolated static func isMLXModelDownloaded() -> Bool {
        #if canImport(MLXLLM)
        return MLXSummarizationService.isModelCached
        #else
        return MLXSummarizationServiceStub.isModelCached
        #endif
    }

    nonisolated static var estimatedMLXModelSize: String { "~1.8 GB" }

    func deleteMLXModel() throws {
        let modelDir = Self.mlxModelsBaseURL
        if fileManager.fileExists(atPath: modelDir.path) {
            try fileManager.removeItem(at: modelDir)
        }
        mlxModelState = .notDownloaded
    }

    func refreshMLXState() {
        mlxModelState = Self.isMLXModelDownloaded() ? .ready : .notDownloaded
    }
}
