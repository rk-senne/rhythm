import ComposableArchitecture
import Foundation

/// Persisted flag for whether first-run onboarding has completed.
/// Kept lightweight (UserDefaults) so the app can gate synchronously at launch
/// with no flicker. Not injected — this is a simple first-run marker.
enum OnboardingStatus {
    private static let key = "rhythm.onboardingComplete.v1"
    static var isComplete: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markComplete() { UserDefaults.standard.set(true, forKey: key) }
}

@Reducer
struct OnboardingFeature {
    // Research rec #1 (docs/RESEARCH_FINDINGS_2026.md): deliver a first-value
    // moment (a real breathing reset) BEFORE asking for notifications/health.
    // Permission prompts come only after the user has felt the core loop.
    enum Step: Equatable, CaseIterable {
        case welcome, miniCycle, duration, notifications, healthKit, done
    }

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
                case .welcome:
                    state.step = .miniCycle
                case .miniCycle:
                    state.step = .duration
                case .duration:
                    state.step = .notifications
                case .notifications:
                    state.step = .healthKit
                case .healthKit:
                    state.step = .done
                    return .send(.completed(focusDuration: state.selectedDuration))
                case .done:
                    break
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
