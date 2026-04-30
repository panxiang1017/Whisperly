import Foundation

@MainActor
protocol EntitlementProviding: AnyObject {
    var isPro: Bool { get }
}

extension StoreManager: EntitlementProviding {}

/// Mock entitlement provider for tests and previews.
@Observable
@MainActor
final class MockEntitlementService: EntitlementProviding {
    var isPro: Bool

    init(isPro: Bool = false) {
        self.isPro = isPro
    }
}
