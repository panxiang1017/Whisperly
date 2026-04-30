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
    let modelManager: ModelManager

    init(
        recorder: any RecordingServiceProtocol = AVAudioEngineRecordingService(),
        transcriptionService: (any TranscriptionServiceProtocol)? = nil,
        diarizationService: any DiarizationServiceProtocol = FluidAudioDiarizationService(),
        summarizationService: any SummarizationServiceProtocol = MockSummarizationService(),
        repository: any MeetingRepositoryProtocol,
        searchService: (any SearchServiceProtocol)? = nil,
        syncCoordinator: any SyncCoordinatorProtocol = CloudKitSyncCoordinator(),
        exportService: any ExportServiceProtocol = ExportService(),
        storeManager: StoreManager = StoreManager(),
        modelManager: ModelManager = ModelManager()
    ) {
        self.recorder = recorder
        self.modelManager = modelManager
        self.transcriptionService = transcriptionService
            ?? WhisperKitTranscriptionService(modelManager: modelManager)
        self.diarizationService = diarizationService
        self.summarizationService = summarizationService
        self.repository = repository
        self.searchService = searchService ?? (try? GRDBSearchService()) ?? StubSearchService()
        self.syncCoordinator = syncCoordinator
        self.exportService = exportService
        self.storeManager = storeManager
    }

    func makeRecordingViewModel() -> RecordingViewModel {
        let pipeline = MeetingPipeline(
            transcriptionService: transcriptionService,
            diarizationService: diarizationService,
            summarizationService: summarizationService,
            repository: repository,
            searchService: searchService
        )

        return RecordingViewModel(
            recorder: recorder,
            entitlementProvider: storeManager,
            pipeline: pipeline,
            modelManager: modelManager
        )
    }
}
