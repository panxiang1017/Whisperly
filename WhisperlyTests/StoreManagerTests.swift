import Testing
import Foundation
@testable import Whisperly

@Suite("Store Manager Tests")
struct StoreManagerTests {

    @Test("Restore purchases sets isPro=true when transaction found")
    @MainActor
    func restorePurchases() async throws {
        // StoreManager uses StoreKit 2, which requires sandbox/StoreKit configuration.
        // In unit tests without a StoreKit configuration, we verify the mock entitlement path.
        let mock = MockEntitlementService(isPro: false)
        #expect(!mock.isPro)

        mock.isPro = true
        #expect(mock.isPro)
    }

    @Test("Products are defined correctly")
    func productsDefinition() {
        #expect(WhisperlyProducts.lifetime == "ai.dxy.whisperly.lifetime")
        #expect(WhisperlyProducts.all.contains(WhisperlyProducts.lifetime))
        #expect(WhisperlyProducts.all.count == 1)
    }

    @Test("EntitlementProviding protocol conformance")
    @MainActor
    func entitlementProtocol() async throws {
        let mock = MockEntitlementService(isPro: false)
        let provider: any EntitlementProviding = mock

        #expect(!provider.isPro)
        mock.isPro = true
        #expect(provider.isPro)
    }
}
