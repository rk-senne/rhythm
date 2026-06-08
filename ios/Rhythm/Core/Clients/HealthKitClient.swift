import Foundation
import HealthKit
import ComposableArchitecture

@DependencyClient
struct HealthKitClient {
    var requestAuthorization: @Sendable () async throws -> Void
    var logWaterIntake: @Sendable (Int) async throws -> Void // ml
}

extension HealthKitClient: DependencyKey {
    static let liveValue: HealthKitClient = {
        let store = HKHealthStore()
        let waterType = HKQuantityType(.dietaryWater)
        return HealthKitClient(
            requestAuthorization: {
                try await store.requestAuthorization(toShare: [waterType], read: [waterType])
            },
            logWaterIntake: { ml in
                let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
                let sample = HKQuantitySample(type: waterType, quantity: quantity, start: .now, end: .now)
                try await store.save(sample)
            }
        )
    }()
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}
