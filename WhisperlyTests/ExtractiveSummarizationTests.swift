import Testing
import Foundation
@testable import Whisperly

@Suite("Extractive Summarization Tests")
struct ExtractiveSummarizationTests {

    private func makeSegments(_ texts: [String]) -> [TranscriptSegmentDTO] {
        texts.enumerated().map { index, text in
            TranscriptSegmentDTO(
                startTime: Double(index) * 10,
                endTime: Double(index + 1) * 10,
                text: text
            )
        }
    }

    @Test("Extractive summarization returns non-empty results for valid transcript")
    func summarizesValidTranscript() async throws {
        let service = ExtractiveSummarizationService()
        let segments = makeSegments([
            "The team reviewed the current project timeline and agreed on the next steps.",
            "We need to finish the database migration before the end of this week.",
            "John will prepare the testing report and share it with everyone.",
            "The architecture review was completed successfully with no major issues found.",
            "Sarah should schedule a follow-up meeting for next Monday to review progress.",
            "Performance testing showed a 20% improvement after the latest optimization.",
            "The budget for Q3 was approved by the finance team yesterday.",
            "We discussed potential risks including third-party API rate limiting.",
        ])

        let result = try await service.summarize(transcript: segments)

        #expect(result.engineType == .extractive)
        #expect(!result.summary.isEmpty)
        #expect(!result.keyPoints.isEmpty)
        #expect(result.keyPoints.count >= 3)
        #expect(result.keyPoints.count <= 7)
    }

    @Test("Action items detected from English action verbs")
    func detectsEnglishActionItems() async throws {
        let service = ExtractiveSummarizationService()
        let segments = makeSegments([
            "The weather was nice today and everyone enjoyed lunch.",
            "John will prepare the quarterly report by Friday.",
            "We need to update the documentation before release.",
            "The office plants look healthy this month.",
            "Please send the meeting notes to the whole team.",
        ])

        let result = try await service.summarize(transcript: segments)

        #expect(result.actionItems.count >= 3)
        #expect(result.actionItems.contains { $0.contains("prepare") || $0.contains("will") })
        #expect(result.actionItems.contains { $0.contains("update") || $0.contains("need to") })
        #expect(result.actionItems.contains { $0.contains("send") || $0.contains("Please") })
    }

    @Test("Action items detected from Chinese action patterns")
    func detectsChineseActionItems() async throws {
        let service = ExtractiveSummarizationService()
        let segments = makeSegments([
            "今天的天气很好。",
            "需要在本周五之前完成数据库迁移。",
            "张三应该准备测试报告。",
        ])

        let result = try await service.summarize(transcript: segments)

        #expect(result.actionItems.count >= 2)
    }

    @Test("Empty transcript returns empty summary")
    func emptyTranscript() async throws {
        let service = ExtractiveSummarizationService()
        let result = try await service.summarize(transcript: [])

        #expect(result.summary.isEmpty)
        #expect(result.keyPoints.isEmpty)
        #expect(result.actionItems.isEmpty)
        #expect(result.engineType == .extractive)
    }

    @Test("Single segment transcript returns that segment")
    func singleSegment() async throws {
        let service = ExtractiveSummarizationService()
        let segments = makeSegments([
            "We should review the pull request before merging it into the main branch.",
        ])

        let result = try await service.summarize(transcript: segments)

        #expect(!result.summary.isEmpty)
        #expect(result.engineType == .extractive)
    }
}
