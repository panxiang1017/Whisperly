import Foundation

protocol SyncCoordinatorProtocol: Sendable {
    var isSyncing: Bool { get }
    func enableSync() async throws
    func disableSync() async throws
}

/// CloudKit sync coordinator for SwiftData.
///
/// Sync is toggled via a UserDefaults flag. Because SwiftData's
/// `ModelConfiguration.cloudKitDatabase` is set at container creation time,
/// toggling requires re-creating the ModelContainer on next app launch.
///
/// Default: **OFF** (privacy-first).
final class CloudKitSyncCoordinator: SyncCoordinatorProtocol, Sendable {
    private static let syncEnabledKey = "iCloudSyncEnabled"

    var isSyncing: Bool {
        UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
    }

    func enableSync() async throws {
        UserDefaults.standard.set(true, forKey: Self.syncEnabledKey)
        // Container will be recreated on next app launch with
        // cloudKitDatabase: .private("iCloud.ai.dxy.Whisperly")
    }

    func disableSync() async throws {
        UserDefaults.standard.set(false, forKey: Self.syncEnabledKey)
        // Container will be recreated on next app launch without CloudKit
    }

    /// Reads the sync preference. Used by WhisperlyApp to configure the ModelContainer.
    static var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledKey)
    }
}

/// Stub implementation for testing. No-op for all operations.
final class StubSyncCoordinator: SyncCoordinatorProtocol, Sendable {
    let isSyncing = false

    func enableSync() async throws {
        // No-op in tests
    }

    func disableSync() async throws {
        // No-op in tests
    }
}
