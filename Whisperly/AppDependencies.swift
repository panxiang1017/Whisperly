import Foundation
import SwiftData

@MainActor
@Observable
final class AppDependencies {
    let recorder: any RecordingServiceProtocol
    let transcriptionService: any TranscriptionServiceProtocol
    let diarizationService: any DiarizationServiceProtocol
    let summarizationService: any SummarizationServiceProtocol
    let repository: any MeetingRepositoryProtocol
    let searchService: any SearchServiceProtocol
    let syncCoordinator: any SyncCoordinatorProtocol
    let exportService: any ExportServiceProtocol
    let storeManager: StoreManager

    init(
        recorder: any RecordingServiceProtocol = MockRecordingService(),
        transcriptionService: any TranscriptionServiceProtocol = MockTranscriptionService(),
        diarizationService: any DiarizationServiceProtocol = MockDiarizationService(),
        summarizationService: any SummarizationServiceProtocol = MockSummarizationService(),
        repository: any MeetingRepositoryProtocol,
        searchService: any SearchServiceProtocol = StubSearchService(),
        syncCoordinator: any SyncCoordinatorProtocol = StubSyncCoordinator(),
        exportService: any ExportServiceProtocol = ExportService(),
        storeManager: StoreManager = StoreManager()
    ) {
        self.recorder = recorder
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.summarizationService = summarizationService
        self.repository = repository
        self.searchService = searchService
        self.syncCoordinator = syncCoordinator
        self.exportService = exportService
        self.storeManager = storeManager
    }

    func makeRecordingViewModel() -> RecordingViewModel {
        let pipeline = MeetingPipeline(
            transcriptionService: transcriptionService,
            diarizationService: diarizationService,
            summarizationService: summarizationService,
            repository: repository
        )

        return RecordingViewModel(
            recorder: recorder,
            entitlementProvider: storeManager,
            pipeline: pipeline
        )
    }
}
