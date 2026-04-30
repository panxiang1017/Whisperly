import Foundation
import NaturalLanguage

final class ExtractiveSummarizationService: SummarizationServiceProtocol, Sendable {

    func summarize(transcript: [TranscriptSegmentDTO]) async throws -> MeetingSummaryDTO {
        let sentences = extractSentences(from: transcript)

        guard sentences.count > 1 else {
            let text = sentences.first ?? ""
            return MeetingSummaryDTO(
                summary: text,
                keyPoints: text.isEmpty ? [] : [text],
                actionItems: extractActionItems(from: sentences),
                engineType: .extractive
            )
        }

        let scores = computeTFIDFScores(sentences)

        let ranked = scores.enumerated()
            .sorted { $0.element > $1.element }

        // Summary: top sentences preserving original order
        let summaryCount = max(2, min(5, sentences.count / 3))
        let summaryIndices = Set(ranked.prefix(summaryCount).map(\.offset))
        let summary = sentences.enumerated()
            .filter { summaryIndices.contains($0.offset) }
            .map(\.element)
            .joined(separator: " ")

        // Key points: top ranked in original order
        let keyPointCount = max(3, min(7, sentences.count / 2))
        let keyPoints = ranked.prefix(keyPointCount)
            .sorted { $0.offset < $1.offset }
            .map { sentences[$0.offset] }

        let actionItems = extractActionItems(from: sentences)

        return MeetingSummaryDTO(
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            engineType: .extractive
        )
    }

    // MARK: - Sentence Extraction

    private func extractSentences(from transcript: [TranscriptSegmentDTO]) -> [String] {
        let fullText = transcript.map(\.text).joined(separator: " ")
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = fullText

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: fullText.startIndex..<fullText.endIndex) { range, _ in
            let sentence = String(fullText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 5 {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    // MARK: - TF-IDF

    private func computeTFIDFScores(_ sentences: [String]) -> [Double] {
        let tokenized = sentences.map { tokenize($0) }

        // Document frequency: how many sentences contain each term
        var df: [String: Int] = [:]
        for tokens in tokenized {
            for word in Set(tokens) {
                df[word, default: 0] += 1
            }
        }

        let n = Double(sentences.count)

        return tokenized.map { tokens -> Double in
            guard !tokens.isEmpty else { return 0 }

            var tf: [String: Int] = [:]
            for word in tokens {
                tf[word, default: 0] += 1
            }

            var score = 0.0
            for (word, count) in tf {
                let termFreq = Double(count) / Double(tokens.count)
                let idf = log(n / Double(df[word] ?? 1))
                score += termFreq * idf
            }

            // Slight boost for medium-length sentences (not too short, not too long)
            let lengthFactor = min(1.0, Double(tokens.count) / 5.0)
            return score * lengthFactor
        }
    }

    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if word.count > 2 {
                words.append(word)
            }
            return true
        }

        return words
    }

    // MARK: - Action Item Extraction

    private func extractActionItems(from sentences: [String]) -> [String] {
        let englishPatterns = [
            "\\bwill\\b", "\\bneed to\\b", "\\bshould\\b", "\\bmust\\b",
            "\\baction\\b", "\\btodo\\b", "\\bfollow.?up\\b",
            "\\bdeadline\\b", "\\bresponsible\\b", "\\bassign",
            "\\blet'?s\\b", "\\bplease\\b", "\\bensure\\b", "\\bmake sure\\b",
            "\\bschedule\\b", "\\breview\\b", "\\bupdate\\b", "\\bprepare\\b",
            "\\bcomplete\\b", "\\bfinish\\b", "\\bsubmit\\b", "\\bsend\\b",
        ]

        let chinesePatterns = [
            "需要", "应该", "必须", "计划", "负责",
            "行动项", "待办", "跟进", "截止",
            "确保", "安排", "审查", "更新", "准备",
            "完成", "提交", "发送",
        ]

        let combinedPattern = (englishPatterns + chinesePatterns).joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: [.caseInsensitive]) else {
            return []
        }

        return sentences.filter { sentence in
            let range = NSRange(sentence.startIndex..., in: sentence)
            return regex.firstMatch(in: sentence, range: range) != nil
        }
    }
}
