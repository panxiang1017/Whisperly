import Foundation

struct TranscriptChunker: Sendable {
    let maxCharacters: Int

    init(maxCharacters: Int = 12_000) {
        self.maxCharacters = maxCharacters
    }

    /// Splits transcript segments into chunks that respect speaker turn boundaries.
    ///
    /// - Prefers splitting at points where the speaker changes.
    /// - If a single speaker talks past `maxCharacters`, forces a split at the segment boundary.
    /// - Returns a single chunk if the total text is within the limit.
    func chunk(segments: [TranscriptSegmentDTO]) -> [[TranscriptSegmentDTO]] {
        guard !segments.isEmpty else { return [] }

        let totalChars = segments.reduce(0) { $0 + $1.text.count }
        if totalChars <= maxCharacters {
            return [segments]
        }

        var chunks: [[TranscriptSegmentDTO]] = []
        var current: [TranscriptSegmentDTO] = []
        var currentChars = 0

        for segment in segments {
            let segChars = segment.text.count
            let wouldExceed = currentChars + segChars > maxCharacters
            let isTurnBoundary = !current.isEmpty && segment.speakerID != current.last?.speakerID

            // Split when we've exceeded the limit AND hit a speaker turn, or significantly exceeded
            if wouldExceed && !current.isEmpty {
                if isTurnBoundary || currentChars >= maxCharacters {
                    chunks.append(current)
                    current = []
                    currentChars = 0
                }
            }

            current.append(segment)
            currentChars += segChars
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }

    /// Formats a chunk of segments into a single transcript string with speaker labels.
    static func formatChunk(_ segments: [TranscriptSegmentDTO]) -> String {
        segments.map(\.text).joined(separator: " ")
    }
}
