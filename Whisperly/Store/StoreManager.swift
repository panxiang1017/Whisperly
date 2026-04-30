import Foundation
import StoreKit

@Observable
@MainActor
final class StoreManager {
    private(set) var isPro: Bool = false
    private(set) var product: Product?
    private(set) var isLoading: Bool = false
    var purchaseError: String?

    private static let cacheKey = "whisperly_isPro_cached"
    private var updateListenerTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProduct() }
        Task { await refreshEntitlements() }
    }

    private nonisolated func checkVerifiedNonisolated<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: WhisperlyProducts.all)
            product = products.first
        } catch {
            purchaseError = String(localized: "Unable to load product. Please check your connection.")
        }
    }

    func purchase() async throws {
        guard let product else {
            purchaseError = String(localized: "Product not available. Please try again later.")
            return
        }
        purchaseError = nil

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled:
            break
        case .pending:
            purchaseError = String(localized: "Purchase is pending approval.")
        @unknown default:
            purchaseError = String(localized: "An unknown error occurred.")
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = String(localized: "Unable to restore purchases. Please try again.")
        }
    }

    private func refreshEntitlements() async {
        var foundPro = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == WhisperlyProducts.lifetime,
               transaction.revocationDate == nil
            {
                foundPro = true
                break
            }
        }
        isPro = foundPro
        UserDefaults.standard.set(foundPro, forKey: Self.cacheKey)
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerifiedNonisolated(result) {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
