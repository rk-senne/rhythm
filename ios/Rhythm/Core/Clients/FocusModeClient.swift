import Foundation
import ComposableArchitecture
import ManagedSettings

@DependencyClient
struct FocusModeClient {
    var enable: @Sendable () async throws -> Void
    var disable: @Sendable () async throws -> Void
}

extension FocusModeClient: DependencyKey {
    static let liveValue: FocusModeClient = {
        let store = ManagedSettingsStore()
        return FocusModeClient(
            enable: {
                store.shield.applicationCategories = .all()
            },
            disable: {
                store.clearAllSettings()
            }
        )
    }()
}

extension DependencyValues {
    var focusModeClient: FocusModeClient {
        get { self[FocusModeClient.self] }
        set { self[FocusModeClient.self] = newValue }
    }
}
