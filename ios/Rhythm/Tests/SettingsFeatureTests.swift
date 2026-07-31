import ComposableArchitecture
import XCTest
@testable import Rhythm

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

@MainActor
final class SettingsFeatureTests: XCTestCase {

    func testOnAppearLoadsSettingsAndSignInStatus() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient.load = {
                let s = UserSettings()
                s.focusDurationMinutes = 60
                s.dailyHydrationGoalMl = 1500
                return s
            }
            $0.keychainClient.load = { _ in "access-token" } // signed in
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)
        await store.receive(\.signInResult)

        XCTAssertTrue(store.state.isLoaded)
        XCTAssertEqual(store.state.focusDurationMinutes, 60)
        XCTAssertEqual(store.state.dailyHydrationGoalMl, 1500)
        XCTAssertTrue(store.state.isSignedIn)
    }

    func testBindingTriggersSave() async {
        let savedDuration = Box<Int?>(nil)
        var initial = SettingsFeature.State()
        initial.isLoaded = true

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient.save = { settings in savedDuration.value = settings.focusDurationMinutes }
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.focusDurationMinutes, 45)))
        await store.receive(\.save)
        await store.finish()

        XCTAssertEqual(savedDuration.value, 45, "changing a setting should persist it")
    }

    func testSignInPersistsTokens() async {
        let savedKeys = Box<[String]>([])
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.authClient.signInWithApple = { "identity-token" }
            $0.authClient.exchangeToken = { _ in TokenPair(accessToken: "acc", refreshToken: "ref") }
            $0.keychainClient.save = { key, _ in savedKeys.value.append(key) }
        }
        store.exhaustivity = .off

        await store.send(.signInTapped)
        await store.receive(\.signInResult)
        await store.finish()

        XCTAssertTrue(store.state.isSignedIn)
        XCTAssertEqual(Set(savedKeys.value), ["access_token", "refresh_token"])
    }
}
