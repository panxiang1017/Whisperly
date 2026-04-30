import Foundation
import GRDB

/// Full-text search service backed by SQLite FTS5 via GRDB.
/// Maintains a parallel index alongside SwiftData — stores only searchable text,
/// not the authoritative meeting data.
final class GRDBSearchService: SearchServiceProtocol, @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    init() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dbDir = appSupport.appendingPathComponent("Whisperly", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("search.sqlite").path

        dbQueue = try DatabaseQueue(path: dbPath)
        try Self.migrate(dbQueue)
    }

    /// Test-only initializer using an in-memory database.
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()
        try Self.migrate(dbQueue)
    }

    // MARK: - Schema

    private static func migrate(_ db: DatabaseQueue) throws {
        try db.write { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS meeting_search
                USING fts5(meeting_id UNINDEXED, content, tokenize='unicode61')
                """)
        }
    }

    // MARK: - SearchServiceProtocol

    func search(query: String) async throws -> [UUID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Escape double quotes and wrap each word for FTS5 prefix matching.
        let terms = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " ")

        return try await dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT DISTINCT meeting_id FROM meeting_search WHERE meeting_search MATCH ?",
                arguments: [terms]
            )
            return rows.compactMap { row -> UUID? in
                guard let idString: String = row["meeting_id"] else { return nil }
                return UUID(uuidString: idString)
            }
        }
    }

    func indexMeeting(id: UUID, text: String) async throws {
        try await dbQueue.write { db in
            // Remove any existing index entry for this meeting, then insert fresh.
            try db.execute(
                sql: "DELETE FROM meeting_search WHERE meeting_id = ?",
                arguments: [id.uuidString]
            )
            try db.execute(
                sql: "INSERT INTO meeting_search (meeting_id, content) VALUES (?, ?)",
                arguments: [id.uuidString, text]
            )
        }
    }

    /// Removes a meeting's index entry.
    func removeIndex(for id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM meeting_search WHERE meeting_id = ?",
                arguments: [id.uuidString]
            )
        }
    }
}
