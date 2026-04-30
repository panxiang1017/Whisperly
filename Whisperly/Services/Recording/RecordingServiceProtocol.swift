import Foundation

protocol RecordingServiceProtocol: AnyObject, Sendable {
    var levelStream: AsyncStream<Float> { get }
    var isRecording: Bool { get }
    func start() async throws
    func stop() async throws -> URL
}

enum RecordingError: Error, LocalizedError {
    case noOutputFile
    case engineStartFailed
    case alreadyRecording
    case notRecording
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noOutputFile:
            String(localized: "No audio file was produced.")
        case .engineStartFailed:
            String(localized: "Failed to start the audio engine.")
        case .alreadyRecording:
            String(localized: "A recording is already in progress.")
        case .notRecording:
            String(localized: "No recording is in progress.")
        case .permissionDenied:
            String(localized: "Microphone access was denied.")
        }
    }
}
