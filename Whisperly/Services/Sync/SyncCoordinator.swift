import Foundation

protocol SyncCoordinatorProtocol: Sendable {
    var isSyncing: Bool { get }
    func enableSync() async throws
    func disableSync() async throws
}

/// Stub implementation for Phase 1. Real CloudKit sync in Phase 2.
final class StubSyncCoordinator: SyncCoordinatorProtocol, Sendable {
    let isSyncing = false

    func enableSync() async throws {
        // No-op in Phase 1
    }

    func disableSync() async throws {
        // No-op in Phase 1
    }
}
