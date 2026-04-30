import Testing
import Foundation
@testable import Whisperly

@Suite("GRDB Search Service Tests")
struct GRDBSearchServiceTests {

    @Test("Index and search returns matching meeting IDs")
    func indexAndSearch() async throws {
        let service = try GRDBSearchService(inMemory: true)

        let id1 = UUID()
        let id2 = UUID()

        try await service.indexMeeting(id: id1, text: "We discussed the quarterly budget and revenue targets")
        try await service.indexMeeting(id: id2, text: "The engineering team reviewed the sprint backlog")

        let budgetResults = try await service.search(query: "budget")
        #expect(budgetResults.contains(id1))
        #expect(!budgetResults.contains(id2))

        let teamResults = try await service.search(query: "engineering team")
        #expect(teamResults.contains(id2))
        #expect(!teamResults.contains(id1))
    }

    @Test("Empty query returns empty results")
    func emptyQuery() async throws {
        let service = try GRDBSearchService(inMemory: true)

        let id = UUID()
        try await service.indexMeeting(id: id, text: "Some meeting text")

        let results = try await service.search(query: "")
        #expect(results.isEmpty)

        let whitespaceResults = try await service.search(query: "   ")
        #expect(whitespaceResults.isEmpty)
    }

    @Test("Re-indexing replaces previous content")
    func reindex() async throws {
        let service = try GRDBSearchService(inMemory: true)

        let id = UUID()
        try await service.indexMeeting(id: id, text: "original content about marketing")
        try await service.indexMeeting(id: id, text: "updated content about engineering")

        let marketingResults = try await service.search(query: "marketing")
        #expect(marketingResults.isEmpty)

        let engineeringResults = try await service.search(query: "engineering")
        #expect(engineeringResults.contains(id))
    }

    @Test("Remove index clears meeting from search")
    func removeIndex() async throws {
        let service = try GRDBSearchService(inMemory: true)

        let id = UUID()
        try await service.indexMeeting(id: id, text: "searchable meeting content")

        var results = try await service.search(query: "searchable")
        #expect(!results.isEmpty)

        try service.removeIndex(for: id)

        results = try await service.search(query: "searchable")
        #expect(results.isEmpty)
    }

    @Test("Prefix search matches partial words")
    func prefixSearch() async throws {
        let service = try GRDBSearchService(inMemory: true)

        let id = UUID()
        try await service.indexMeeting(id: id, text: "The infrastructure migration is planned for next quarter")

        let results = try await service.search(query: "infra")
        #expect(results.contains(id))
    }
}
