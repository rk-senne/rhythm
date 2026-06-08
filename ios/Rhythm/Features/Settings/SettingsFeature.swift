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
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loaded(UserSettings?)
        case save
    }

    @Dependency(\.settingsClient) var settingsClient

    var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.focusDurationMinutes) { _, _ in .send(.save) }
            .onChange(of: \.dailyHydrationGoalMl) { _, _ in .send(.save) }
            .onChange(of: \.enableFocusMode) { _, _ in .send(.save) }
            .onChange(of: \.enableSoundAlerts) { _, _ in .send(.save) }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                guard !state.isLoaded else { return .none }
                return .run { send in
                    let settings = try? await settingsClient.load()
                    await send(.loaded(settings))
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
            }
        }
    }
}
