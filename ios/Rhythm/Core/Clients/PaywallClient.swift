import ComposableArchitecture
import RevenueCat

@DependencyClient
struct PaywallClient {
    var configure: @Sendable () async -> Void = {}
    var checkProStatus: @Sendable () async -> Bool = { false }
    var getOfferings: @Sendable () async throws -> [PackageInfo] = { [] }
    var purchase: @Sendable (String) async throws -> Bool = { _ in false }
    var restore: @Sendable () async throws -> Bool = { false }
}

struct PackageInfo: Equatable, Identifiable {
    let id: String
    let title: String
    let price: String
    let period: String
}

extension PaywallClient: DependencyKey {
    static let liveValue = PaywallClient(
        configure: {
            Purchases.configure(withAPIKey: "your_revenuecat_api_key")
        },
        checkProStatus: {
            let info = try? await Purchases.shared.customerInfo()
            return info?.entitlements["pro"]?.isActive == true
        },
        getOfferings: {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { return [] }
            return current.availablePackages.map {
                PackageInfo(
                    id: $0.identifier,
                    title: $0.storeProduct.localizedTitle,
                    price: $0.localizedPriceString,
                    period: $0.storeProduct.subscriptionPeriod?.periodTitle ?? ""
                )
            }
        },
        purchase: { packageId in
            let offerings = try await Purchases.shared.offerings()
            guard let pkg = offerings.current?.availablePackages.first(where: { $0.identifier == packageId }) else {
                return false
            }
            let (_, info, _) = try await Purchases.shared.purchase(package: pkg)
            return info.entitlements["pro"]?.isActive == true
        },
        restore: {
            let info = try await Purchases.shared.restorePurchases()
            return info.entitlements["pro"]?.isActive == true
        }
    )
}

extension DependencyValues {
    var paywallClient: PaywallClient {
        get { self[PaywallClient.self] }
        set { self[PaywallClient.self] = newValue }
    }
}

private extension SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .month: return value == 1 ? "Monthly" : "\(value) months"
        case .year: return "Yearly"
        case .week: return "Weekly"
        default: return ""
        }
    }
}
