import ComposableArchitecture
import Foundation

@Reducer
struct TimerFeature {
    @ObservableState
    struct State: Equatable {
        var secondsRemaining: Int = 0
        var isRunning: Bool = false
        var focusDuration: Int = 5400 // 90 min default
        var startedAt: Date?
    }

    enum Action {
        case startTapped
        case stopTapped
        case timerTick(Int)
        case timerFinished
    }

    @Dependency(\.timerClient) var timerClient
    @Dependency(\.liveActivityClient) var liveActivityClient
    @Dependency(\.focusModeClient) var focusModeClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now

    private enum CancelID { case timer }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startTapped:
                state.isRunning = true
                state.secondsRemaining = state.focusDuration
                state.startedAt = now
                let duration = state.focusDuration
                return .run { send in
                    try? await liveActivityClient.start(duration)
                    try? await focusModeClient.enable()
                    _ = try? await notificationClient.requestAuthorization()
                    try? await notificationClient.scheduleRitualReminder(
                        Date.now.addingTimeInterval(TimeInterval(duration))
                    )
                    for await remaining in await timerClient.start(duration) {
                        await send(.timerTick(remaining))
                    }
                    await send(.timerFinished)
                }.cancellable(id: CancelID.timer)

            case .stopTapped:
                state.isRunning = false
                state.startedAt = nil
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        try? await liveActivityClient.stop()
                        try? await focusModeClient.disable()
                    }
                )

            case let .timerTick(remaining):
                state.secondsRemaining = remaining
                return .none

            case .timerFinished:
                state.isRunning = false
                return .run { _ in
                    try? await liveActivityClient.stop()
                    try? await focusModeClient.disable()
                }
            }
        }
    }
}
