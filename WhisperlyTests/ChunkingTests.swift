import Testing
import Foundation
@testable import Whisperly

@Suite("Chunking Tests")
struct ChunkingTests {

    private let speakerA = UUID()
    private let speakerB = UUID()

    private func makeSegment(text: String, speaker: UUID? = nil) -> TranscriptSegmentDTO {
        TranscriptSegmentDTO(
            startTime: 0,
            endTime: 10,
            text: text,
            speakerID: speaker
        )
    }

    @Test("Short transcript returns single chunk")
    func shortTranscriptSingleChunk() {
        let chunker = TranscriptChunker(maxCharacters: 1000)
        let segments = [
            makeSegment(text: "Hello, how are you?"),
            makeSegment(text: "I am fine, thank you."),
        ]

        let chunks = chunker.chunk(segments: segments)

        #expect(chunks.count == 1)
        #expect(chunks[0].count == 2)
    }

    @Test("Long transcript splits into multiple chunks")
    func longTranscriptMultipleChunks() {
        let chunker = TranscriptChunker(maxCharacters: 100)
        let segments = (0..<10).map { i in
            makeSegment(
                text: "This is segment number \(i) with enough text to contribute to the character count meaningfully.",
                speaker: i % 2 == 0 ? speakerA : speakerB
            )
        }

        let chunks = chunker.chunk(segments: segments)

        #expect(chunks.count > 1)
        // All segments accounted for
        let totalSegments = chunks.reduce(0) { $0 + $1.count }
        #expect(totalSegments == 10)
    }

    @Test("Splits at speaker turn boundaries")
    func splitsAtSpeakerTurns() {
        let chunker = TranscriptChunker(maxCharacters: 200)

        // Speaker A says a lot, then speaker B starts
        let segments = [
            makeSegment(text: String(repeating: "word ", count: 30), speaker: speakerA),
            makeSegment(text: String(repeating: "more ", count: 30), speaker: speakerA),
            makeSegment(text: "Speaker B starts talking here with new content.", speaker: speakerB),
            makeSegment(text: "Speaker B continues their point.", speaker: speakerB),
        ]

        let chunks = chunker.chunk(segments: segments)

        #expect(chunks.count >= 2)

        // First chunk should contain speaker A's segments
        if chunks.count >= 2 {
            let firstChunkSpeakers = Set(chunks[0].compactMap(\.speakerID))
            #expect(firstChunkSpeakers.contains(speakerA))
        }
    }

    @Test("Empty segments returns empty chunks")
    func emptySegments() {
        let chunker = TranscriptChunker(maxCharacters: 1000)
        let chunks = chunker.chunk(segments: [])
        #expect(chunks.isEmpty)
    }

    @Test("Single large segment handled gracefully")
    func singleLargeSegment() {
        let chunker = TranscriptChunker(maxCharacters: 50)
        let segments = [
            makeSegment(text: String(repeating: "a", count: 200)),
        ]

        let chunks = chunker.chunk(segments: segments)

        #expect(chunks.count == 1)
        #expect(chunks[0].count == 1)
    }

    @Test("Format chunk produces combined text")
    func formatChunk() {
        let segments = [
            makeSegment(text: "Hello world"),
            makeSegment(text: "Good morning"),
        ]

        let text = TranscriptChunker.formatChunk(segments)

        #expect(text == "Hello world Good morning")
    }
}
