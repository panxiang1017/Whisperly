import Foundation

final class MockRecordingService: RecordingServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let _levelStream: AsyncStream<Float>
    private let _levelContinuation: AsyncStream<Float>.Continuation
    private var _isRecording = false
    private var simulationTask: Task<Void, Never>?

    var levelStream: AsyncStream<Float> { _levelStream }

    var isRecording: Bool {
        lock.withLock { _isRecording }
    }

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Float.self)
        _levelStream = stream
        _levelContinuation = continuation
    }

    func start() async throws {
        try lock.withLock {
            guard !_isRecording else { throw RecordingError.alreadyRecording }
            _isRecording = true
        }

        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                let level = Float.random(in: 0.05...0.7)
                self?._levelContinuation.yield(level)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func stop() async throws -> URL {
        try lock.withLock {
            guard _isRecording else { throw RecordingError.notRecording }
            simulationTask?.cancel()
            simulationTask = nil
            _isRecording = false
        }

        _levelContinuation.finish()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-recording-\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }
}
