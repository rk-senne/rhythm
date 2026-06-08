import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    enum Step: Equatable { case welcome, notifications, healthKit, duration, done }

    @ObservableState
    struct State: Equatable {
        var step: Step = .welcome
        var selectedDuration: Int = 90
        var notificationsGranted: Bool = false
        var healthKitGranted: Bool = false
    }

    enum Action {
        case nextTapped
        case requestNotifications
        case notificationsResult(Bool)
        case requestHealthKit
        case healthKitResult(Bool)
        case durationSelected(Int)
        case completed(focusDuration: Int)
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.healthKitClient) var healthKitClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextTapped:
                switch state.step {
                case .welcome: state.step = .notifications
                case .notifications: state.step = .healthKit
                case .healthKit: state.step = .duration
                case .duration:
                    state.step = .done
                    return .send(.completed(focusDuration: state.selectedDuration))
                case .done: break
                }
                return .none

            case .requestNotifications:
                return .run { send in
                    let granted = try await notificationClient.requestAuthorization()
                    await send(.notificationsResult(granted))
                }
            case let .notificationsResult(granted):
                state.notificationsGranted = granted
                return .none

            case .requestHealthKit:
                return .run { send in
                    try await healthKitClient.requestAuthorization()
                    await send(.healthKitResult(true))
                } catch: { _, send in
                    await send(.healthKitResult(false))
                }
            case let .healthKitResult(granted):
                state.healthKitGranted = granted
                return .none

            case let .durationSelected(mins):
                state.selectedDuration = mins
                return .none

            case .completed:
                return .none
            }
        }
    }
}
