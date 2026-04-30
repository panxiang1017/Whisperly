import Foundation

enum PipelineError: Error, LocalizedError {
    case transcriptionFailed(Error)
    case diarizationFailed(Error)
    case summarizationFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let error):
            String(localized: "Transcription failed: \(error.localizedDescription)")
        case .diarizationFailed(let error):
            String(localized: "Diarization failed: \(error.localizedDescription)")
        case .summarizationFailed(let error):
            String(localized: "Summarization failed: \(error.localizedDescription)")
        case .saveFailed(let error):
            String(localized: "Failed to save meeting: \(error.localizedDescription)")
        }
    }
}

enum PipelineStage: Sendable {
    case transcribing
    case diarizing
    case summarizing
    case saving
    case completed
}

@MainActor
final class MeetingPipeline {
    private let transcriptionService: any TranscriptionServiceProtocol
    private let diarizationService: any DiarizationServiceProtocol
    private let summarizationService: any SummarizationServiceProtocol
    private let repository: any MeetingRepositoryProtocol

    var onStageChanged: ((PipelineStage) -> Void)?

    init(
        transcriptionService: any TranscriptionServiceProtocol,
        diarizationService: any DiarizationServiceProtocol,
        summarizationService: any SummarizationServiceProtocol,
        repository: any MeetingRepositoryProtocol
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.summarizationService = summarizationService
        self.repository = repository
    }

    func process(
        audioURL: URL,
        duration: TimeInterval,
        language: String? = nil
    ) async throws -> Meeting {
        onStageChanged?(.transcribing)
        let segments: [TranscriptSegmentDTO]
        do {
            segments = try await transcriptionService.transcribe(audioURL: audioURL, language: language)
        } catch {
            throw PipelineError.transcriptionFailed(error)
        }

        onStageChanged?(.diarizing)
        let diarizedSegments: [TranscriptSegmentDTO]
        let speakers: [SpeakerDTO]
        do {
            (diarizedSegments, speakers) = try await diarizationService.diarize(audioURL: audioURL, segments: segments)
        } catch {
            throw PipelineError.diarizationFailed(error)
        }

        onStageChanged?(.summarizing)
        let summary: MeetingSummaryDTO
        do {
            summary = try await summarizationService.summarize(transcript: diarizedSegments)
        } catch {
            throw PipelineError.summarizationFailed(error)
        }

        onStageChanged?(.saving)
        let title = generateTitle(from: diarizedSegments)
        let meeting: Meeting
        do {
            meeting = try await repository.createMeeting(
                title: title,
                duration: duration,
                audioURL: audioURL,
                segments: diarizedSegments,
                speakers: speakers,
                summary: summary,
                language: language ?? "en"
            )
        } catch {
            throw PipelineError.saveFailed(error)
        }

        onStageChanged?(.completed)
        return meeting
    }

    private func generateTitle(from segments: [TranscriptSegmentDTO]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())

        guard let firstSegment = segments.first else {
            return String(localized: "Meeting \(dateString)")
        }

        let preview = String(firstSegment.text.prefix(40))
        if preview.count < firstSegment.text.count {
            return "\(preview)..."
        }
        return preview
    }
}
