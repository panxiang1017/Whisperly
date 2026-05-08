import Foundation
import SwiftUI

@Observable
@MainActor
final class RecordingViewModel {
    // MARK: - Published State

    private(set) var isRecording = false
    private(set) var elapsedSeconds: Int = 0
    private(set) var remainingSeconds: Int = AppTheme.freeRecordingLimitSeconds
    private(set) var audioLevel: Float = 0
    private(set) var showCountdown = true
    private(set) var pipelineStage: PipelineStage?
    private(set) var isProcessing = false
    var error: Error?

    var isCountdownUrgent: Bool {
        showCountdown && remainingSeconds < 300
    }

    var formattedElapsed: String {
        formatTime(elapsedSeconds)
    }

    var formattedRemaining: String {
        formatTime(remainingSeconds)
    }

    // MARK: - Dependencies

    private let recorder: any RecordingServiceProtocol
    private let entitlementProvider: any EntitlementProviding
    private let pipeline: MeetingPipeline
    private let timeLimitSeconds: Int

    // MARK: - Tasks

    private var countdownTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var recordingStartDate: Date?

    init(
        recorder: any RecordingServiceProtocol,
        entitlementProvider: any EntitlementProviding,
        pipeline: MeetingPipeline,
        timeLimitSeconds: Int = AppTheme.freeRecordingLimitSeconds
    ) {
        self.recorder = recorder
        self.entitlementProvider = entitlementProvider
        self.pipeline = pipeline
        self.timeLimitSeconds = timeLimitSeconds
    }

    // MARK: - Recording Control

    func startRecording() async {
        do {
            // Configure system audio capture preference on macOS.
            #if os(macOS)
            if let avRecorder = recorder as? AVAudioEngineRecordingService {
                avRecorder.captureSystemAudio = UserDefaults.standard.bool(forKey: "captureSystemAudio")
            }
            #endif

            try await recorder.start()
            isRecording = true
            recordingStartDate = Date()
            elapsedSeconds = 0
            remainingSeconds = timeLimitSeconds
            showCountdown = !entitlementProvider.isPro
            error = nil

            startTimers()
        } catch {
            self.error = error
        }
    }

    func stopRecording() async -> Meeting? {
        guard isRecording else { return nil }

        countdownTask?.cancel()
        levelTask?.cancel()

        do {
            let audioURL = try await recorder.stop()
            isRecording = false
            isProcessing = true

            pipeline.onStageChanged = { [weak self] stage in
                self?.pipelineStage = stage
            }

            let meeting = try await pipeline.process(
                audioURL: audioURL,
                duration: TimeInterval(elapsedSeconds)
            )

            isProcessing = false
            pipelineStage = nil
            return meeting
        } catch {
            isRecording = false
            isProcessing = false
            self.error = error
            return nil
        }
    }

    // MARK: - Timers

    private func startTimers() {
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRecording else { return }
                guard let startDate = self.recordingStartDate else { return }

                let elapsed = Int(Date().timeIntervalSince(startDate))
                self.elapsedSeconds = elapsed

                if self.entitlementProvider.isPro {
                    if self.showCountdown {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.showCountdown = false
                        }
                    }
                    continue
                }

                self.remainingSeconds = self.timeLimitSeconds - elapsed

                if self.remainingSeconds <= 0 {
                    _ = await self.stopRecording()
                    return
                }
            }
        }

        levelTask = Task { [weak self] in
            guard let self else { return }
            for await level in self.recorder.levelStream {
                guard !Task.isCancelled else { break }
                self.audioLevel = level
            }
        }
    }

    // MARK: - Formatting

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
