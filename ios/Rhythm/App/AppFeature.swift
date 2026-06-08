import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var timer = TimerFeature.State()
        var ritual = RitualFeature.State()
        var timeline = TimelineFeature.State()
        var settings = SettingsFeature.State()
        var showRitual: Bool = false
        var currentCycleId: UUID?
    }

    enum Action {
        case timer(TimerFeature.Action)
        case ritual(RitualFeature.Action)
        case timeline(TimelineFeature.Action)
        case settings(SettingsFeature.Action)
        case cycleSaved
        case appBecameActive
        case syncCompleted
    }

    @Dependency(\.dataClient) var dataClient
    @Dependency(\.syncClient) var syncClient
    @Dependency(\.keychainClient) var keychainClient

    var body: some ReducerOf<Self> {
        Scope(state: \.timer, action: \.timer) { TimerFeature() }
        Scope(state: \.ritual, action: \.ritual) { RitualFeature() }
        Scope(state: \.timeline, action: \.timeline) { TimelineFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }

        Reduce { state, action in
            switch action {
            case .timer(.timerFinished):
                state.showRitual = true
                state.currentCycleId = UUID()
                return .none

            case .ritual(.completed):
                state.showRitual = false
                let cycleId = state.currentCycleId ?? UUID()
                let duration = state.timer.focusDuration
                let journal = state.ritual.journalText
                let hydrated = state.ritual.hydrated
                // Reset ritual for next time
                state.ritual = RitualFeature.State()
                return .run { send in
                    try await dataClient.saveCycle(cycleId, duration, true)
                    if !journal.isEmpty {
                        try await dataClient.saveJournal(cycleId, journal, nil)
                    }
                    if hydrated {
                        try await dataClient.saveHydration(cycleId, 250)
                    }
                    await send(.cycleSaved)
                }

            case .cycleSaved:
                return .send(.timeline(.onAppear))

            case .appBecameActive:
                return .run { send in
                    guard let token = await keychainClient.load("access_token") else { return }
                    try? await syncClient.pull(token)
                    await send(.syncCompleted)
                }

            case .syncCompleted:
                return .send(.timeline(.onAppear))

            default:
                return .none
            }
        }
    }
}
