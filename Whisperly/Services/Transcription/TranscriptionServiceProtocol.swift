import Foundation

protocol TranscriptionServiceProtocol: Sendable {
    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegmentDTO]
}
