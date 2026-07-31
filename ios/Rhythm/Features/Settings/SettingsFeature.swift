import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var focusDurationMinutes: Int = 90
        var dailyHydrationGoalMl: Int = 2000
        var enableFocusMode: Bool = true
        var enableSoundAlerts: Bool = true
        var isLoaded: Bool = false
        var isSignedIn: Bool = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loaded(UserSettings?)
        case save
        case signInTapped
        case signInResult(Bool)
    }

    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.keychainClient) var keychainClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                // Persist whenever any bound setting changes.
                return .send(.save)
            case .onAppear:
                guard !state.isLoaded else { return .none }
                return .run { send in
                    let settings = try? await settingsClient.load()
                    await send(.loaded(settings))
                    let signedIn = await keychainClient.load("access_token") != nil
                    await send(.signInResult(signedIn))
                }
            case let .loaded(settings):
                state.isLoaded = true
                if let s = settings {
                    state.focusDurationMinutes = s.focusDurationMinutes
                    state.dailyHydrationGoalMl = s.dailyHydrationGoalMl
                    state.enableFocusMode = s.enableFocusMode
                    state.enableSoundAlerts = s.enableSoundAlerts
                }
                return .none
            case .save:
                let settings = UserSettings()
                settings.focusDurationMinutes = state.focusDurationMinutes
                settings.dailyHydrationGoalMl = state.dailyHydrationGoalMl
                settings.enableFocusMode = state.enableFocusMode
                settings.enableSoundAlerts = state.enableSoundAlerts
                return .run { _ in try await settingsClient.save(settings) }

            case .signInTapped:
                // Sign in with Apple, exchange for tokens, and persist them.
                return .run { send in
                    let identity = try await authClient.signInWithApple()
                    let pair = try await authClient.exchangeToken(identity)
                    try await keychainClient.save("access_token", pair.accessToken)
                    try await keychainClient.save("refresh_token", pair.refreshToken)
                    await send(.signInResult(true))
                } catch: { _, send in
                    await send(.signInResult(false))
                }

            case let .signInResult(signedIn):
                state.isSignedIn = signedIn
                return .none
            }
        }
    }
}
