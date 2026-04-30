import AVFoundation
import Foundation
#if os(macOS)
import CoreAudio
#endif

final class AVAudioEngineRecordingService: RecordingServiceProtocol, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var _levelStream: AsyncStream<Float>?
    private var levelContinuation: AsyncStream<Float>.Continuation?
    private var _isRecording = false

    /// When true on macOS, captures system audio via Core Audio Tap alongside the mic.
    var captureSystemAudio = false

    #if os(macOS)
    private var systemTapObjectID: AudioObjectID = 0
    private var systemEngine: AVAudioEngine?
    private var systemAudioFile: AVAudioFile?
    #endif

    var isRecording: Bool { _isRecording }

    var levelStream: AsyncStream<Float> {
        if let existing = _levelStream { return existing }
        let (stream, continuation) = AsyncStream.makeStream(of: Float.self)
        _levelStream = stream
        levelContinuation = continuation
        return stream
    }

    func start() async throws {
        guard !_isRecording else { throw RecordingError.alreadyRecording }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        #endif

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let recordingsDir = documentsDir.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let url = recordingsDir.appendingPathComponent("\(UUID().uuidString).m4a")

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        )

        guard let recordingFormat else {
            throw RecordingError.engineStartFailed
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]

        audioFile = try AVAudioFile(forWriting: url, settings: settings)
        outputURL = url

        // Ensure we have a fresh level stream
        let (stream, continuation) = AsyncStream.makeStream(of: Float.self)
        _levelStream = stream
        levelContinuation = continuation

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            try? self?.audioFile?.write(from: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let normalizedLevel = min(1.0, rms * 5.0)
            self?.levelContinuation?.yield(normalizedLevel)
        }

        #if os(macOS)
        if captureSystemAudio {
            try startSystemAudioCapture(recordingsDir: recordingsDir, sampleRate: inputFormat.sampleRate)
        }
        #endif

        try engine.start()
        _isRecording = true
    }

    func stop() async throws -> URL {
        guard _isRecording else { throw RecordingError.notRecording }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        _isRecording = false
        levelContinuation?.finish()

        #if os(macOS)
        stopSystemAudioCapture()
        #endif

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        guard let url = outputURL else {
            throw RecordingError.noOutputFile
        }
        return url
    }

    // MARK: - macOS Core Audio Tap

    #if os(macOS)
    /// Starts a Core Audio process tap to capture system audio output (macOS 14.2+).
    /// Falls back gracefully if the API is unavailable.
    private func startSystemAudioCapture(recordingsDir: URL, sampleRate: Double) throws {
        guard #available(macOS 14.2, *) else { return }

        // Create a global tap that captures all system audio except our own process.
        let ownPID = AudioObjectID(ProcessInfo.processInfo.processIdentifier)
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [ownPID])

        var tapID: AudioObjectID = 0
        let status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard status == noErr else { return }

        systemTapObjectID = tapID

        // Create a separate AVAudioEngine to capture from the tap device.
        let sysEngine = AVAudioEngine()
        let sysFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        guard let sysFormat else { return }

        let sysURL = recordingsDir.appendingPathComponent("\(UUID().uuidString)-system.m4a")
        let sysSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]

        if let file = try? AVAudioFile(forWriting: sysURL, settings: sysSettings) {
            systemAudioFile = file
            sysEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: sysFormat) { [weak self] buffer, _ in
                try? self?.systemAudioFile?.write(from: buffer)
            }
            try? sysEngine.start()
            systemEngine = sysEngine
        }
    }

    private func stopSystemAudioCapture() {
        systemEngine?.inputNode.removeTap(onBus: 0)
        systemEngine?.stop()
        systemEngine = nil
        systemAudioFile = nil

        if systemTapObjectID != 0 {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(systemTapObjectID)
            }
            systemTapObjectID = 0
        }
    }
    #endif
}
