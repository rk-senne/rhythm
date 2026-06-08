import Foundation
import SwiftData
import ComposableArchitecture

@DependencyClient
struct SettingsClient {
    var load: @Sendable () async throws -> UserSettings? = { nil }
    var save: @Sendable (UserSettings) async throws -> Void = { _ in }
}

extension SettingsClient: DependencyKey {
    static let liveValue = SettingsClient(
        load: {
            try await DataStore.shared.loadSettings()
        },
        save: { settings in
            try await DataStore.shared.saveSettings(settings)
        }
    )
}

extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}
