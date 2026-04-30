import Foundation
import SwiftUI
import WhisperKit

/// Manages on-device model downloads for WhisperKit transcription.
@MainActor
@Observable
final class ModelManager {
    enum ModelState: Equatable, Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    private(set) var whisperModelState: ModelState = .notDownloaded
    private(set) var whisperModelName: String = ""

    private let fileManager = FileManager.default
    private var downloadTask: Task<Void, Never>?

    // MARK: - Storage Paths

    static var modelsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WhisperKit/Models", isDirectory: true)
    }

    // MARK: - Lifecycle

    init() {
        let recommended = Self.recommendedModelName()
        whisperModelName = recommended
        whisperModelState = Self.isModelDownloaded(recommended) ? .ready : .notDownloaded
    }

    /// Test-only initializer that skips model detection.
    init(modelName: String, state: ModelState) {
        self.whisperModelName = modelName
        self.whisperModelState = state
    }

    // MARK: - Model Readiness

    var isReady: Bool {
        whisperModelState == .ready
    }

    // MARK: - Device-Specific Model

    static func recommendedModelName() -> String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(totalMemory) / (1024 * 1024 * 1024)

        if memoryGB >= 6 {
            return "large-v3-turbo"
        } else {
            return "small"
        }
    }

    static func estimatedModelSize(for model: String) -> String {
        switch model {
        case "large-v3-turbo": "~626 MB"
        case "large-v3": "~1.5 GB"
        case "small": "~244 MB"
        case "base": "~74 MB"
        case "tiny": "~39 MB"
        default: String(localized: "Unknown size")
        }
    }

    // MARK: - Download

    func downloadWhisperModel() async {
        guard whisperModelState != .ready else { return }
        whisperModelState = .downloading(progress: 0)

        downloadTask = Task { [whisperModelName] in
            do {
                let modelsDir = Self.modelsBaseURL
                try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)

                _ = try await WhisperKit.download(
                    variant: whisperModelName,
                    downloadBase: modelsDir.path
                )

                whisperModelState = .ready
            } catch {
                if Task.isCancelled {
                    whisperModelState = .notDownloaded
                } else {
                    whisperModelState = .failed(error.localizedDescription)
                }
            }
        }
        await downloadTask?.value
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        whisperModelState = .notDownloaded
    }

    // MARK: - Delete

    func deleteWhisperModel() throws {
        let modelDir = Self.modelsBaseURL.appendingPathComponent(whisperModelName, isDirectory: true)
        if fileManager.fileExists(atPath: modelDir.path) {
            try fileManager.removeItem(at: modelDir)
        }
        whisperModelState = .notDownloaded
    }

    // MARK: - Refresh

    func refreshState() {
        whisperModelState = Self.isModelDownloaded(whisperModelName) ? .ready : .notDownloaded
    }

    // MARK: - Helpers

    static func isModelDownloaded(_ model: String) -> Bool {
        let modelDir = modelsBaseURL.appendingPathComponent(model, isDirectory: true)
        return FileManager.default.fileExists(atPath: modelDir.path)
    }

    var modelFolderURL: URL {
        Self.modelsBaseURL.appendingPathComponent(whisperModelName, isDirectory: true)
    }
}
