import Testing
import Foundation
@testable import Whisperly

@Suite("Countdown Timer Tests")
struct CountdownTimerTests {

    @Test("Free user countdown reaches zero stops recording")
    @MainActor
    func countdownStopsRecording() async throws {
        let mockEntitlement = MockEntitlementService(isPro: false)
        let mockRecorder = MockRecordingService()
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)
        let pipeline = MeetingPipeline(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: MockSummarizationService(),
            repository: repository
        )

        let viewModel = RecordingViewModel(
            recorder: mockRecorder,
            entitlementProvider: mockEntitlement,
            pipeline: pipeline
        )

        await viewModel.startRecording()
        #expect(viewModel.isRecording)
        #expect(viewModel.showCountdown)
        #expect(viewModel.remainingSeconds == AppTheme.freeRecordingLimitSeconds)
    }

    @Test("Pro upgrade mid-countdown removes timer without interrupting")
    @MainActor
    func proUpgradeMidCountdown() async throws {
        let mockEntitlement = MockEntitlementService(isPro: false)
        let mockRecorder = MockRecordingService()
        let container = try TestHelpers.makeTestContainer()
        let repository = SwiftDataMeetingRepository(modelContext: container.mainContext)
        let pipeline = MeetingPipeline(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: MockSummarizationService(),
            repository: repository
        )

        let viewModel = RecordingViewModel(
            recorder: mockRecorder,
            entitlementProvider: mockEntitlement,
            pipeline: pipeline
        )

        await viewModel.startRecording()
        #expect(viewModel.showCountdown)

        // Simulate mid-recording purchase
        mockEntitlement.isPro = true

        // Wait for the timer tick to pick up the change
        try await Task.sleep(for: .seconds(1.5))

        #expect(viewModel.isRecording, "Recording should continue after upgrade")
        #expect(!viewModel.showCountdown, "Countdown should be hidden after upgrade")
    }
}
