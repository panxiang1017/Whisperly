import Foundation

protocol SearchServiceProtocol: Sendable {
    func search(query: String) async throws -> [UUID]
    func indexMeeting(id: UUID, text: String) async throws
}

/// Stub implementation for Phase 1. Real GRDB FTS5 search in Phase 2.
final class StubSearchService: SearchServiceProtocol, Sendable {
    func search(query: String) async throws -> [UUID] {
        []
    }

    func indexMeeting(id: UUID, text: String) async throws {
        // No-op in Phase 1
    }
}
