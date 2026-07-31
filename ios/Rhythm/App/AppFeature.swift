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
        // Non-nil => show first-run onboarding instead of the main app.
        var onboarding: OnboardingFeature.State?
        // Monetization / gating.
        var isPro: Bool = false
        var cyclesCompletedToday: Int = 0
        var hasSeenPaywall: Bool = false
        var paywall: PaywallFeature.State?
        var errorMessage: String?
    }

    enum Action {
        case timer(TimerFeature.Action)
        case ritual(RitualFeature.Action)
        case timeline(TimelineFeature.Action)
        case settings(SettingsFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case cycleSaved
        case appBecameActive
        case syncCompleted
        case ritualDismissed
        case startCycleRequested
        case entitlementsLoaded(isPro: Bool)
        case paywall(PaywallFeature.Action)
        case paywallDismissed
        case saveFailed(String)
        case errorDismissed
    }

    @Dependency(\.dataClient) var dataClient
    @Dependency(\.syncClient) var syncClient
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.paywallClient) var paywallClient
    @Dependency(\.telemetry) var telemetry

    var body: some ReducerOf<Self> {
        Scope(state: \.timer, action: \.timer) { TimerFeature() }
        Scope(state: \.ritual, action: \.ritual) { RitualFeature() }
        Scope(state: \.timeline, action: \.timeline) { TimelineFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }

        // Run the onboarding child before the core reducer, so that when the
        // core clears onboarding on completion the child has already handled the
        // action (avoids "action sent to nil child" runtime warnings).
        EmptyReducer()
            .ifLet(\.onboarding, action: \.onboarding) {
                OnboardingFeature()
            }

        EmptyReducer()
            .ifLet(\.paywall, action: \.paywall) {
                PaywallFeature()
            }

        Reduce { state, action in
            switch action {
            case .timer(.timerFinished):
                state.showRitual = true
                state.currentCycleId = UUID()
                return .none

            case .ritual(.completed):
                state.showRitual = false
                let cycleId = state.currentCycleId ?? UUID()
                let journalId = UUID()
                let hydrationId = UUID()
                let duration = state.timer.focusDuration
                let startedAt = state.timer.startedAt
                let journal = state.ritual.journalText
                let hydrated = state.ritual.hydrated
                // Reset ritual for next time
                state.ritual = RitualFeature.State()
                return .run { send in
                    var changes: [SyncChange] = []

                    try await dataClient.saveCycle(cycleId, duration, true)
                    changes.append(SyncPayloads.cycleChange(
                        id: cycleId,
                        startedAt: startedAt ?? Date(),
                        endedAt: Date(),
                        focusDuration: duration,
                        ritualCompleted: true
                    ))

                    if !journal.isEmpty {
                        try await dataClient.saveJournal(journalId, cycleId, journal, nil)
                        changes.append(SyncPayloads.journalChange(id: journalId, cycleId: cycleId, text: journal, mood: nil))
                    }

                    if hydrated {
                        try await dataClient.saveHydration(hydrationId, cycleId, 250)
                        // Mirror the hydration to Apple Health (best-effort).
                        try? await healthKitClient.logWaterIntake(250)
                        changes.append(SyncPayloads.hydrationChange(id: hydrationId, cycleId: cycleId, amountMl: 250))
                    }

                    // Best-effort push to the server; reconciled on next pull if it fails.
                    if let token = await keychainClient.load("access_token") {
                        try? await syncClient.pushChanges(changes, token)
                    }
                    await send(.cycleSaved)
                } catch: { error, send in
                    // A local save failed — surface it rather than losing it silently.
                    await send(.saveFailed(error.localizedDescription))
                }

            case .cycleSaved:
                return .merge(
                    .send(.timeline(.onAppear)),
                    .run { _ in telemetry.track(.cycleCompleted) }
                )

            case .appBecameActive:
                return .merge(
                    .run { send in
                        // Configure the purchases SDK before the first entitlement
                        // check (accessing it unconfigured is a fatal error).
                        await paywallClient.configure()
                        await send(.entitlementsLoaded(isPro: await paywallClient.checkProStatus()))
                    },
                    .run { send in
                        guard let access = await keychainClient.load("access_token") else { return }
                        do {
                            try await syncClient.pull(access)
                        } catch SyncError.unauthorized {
                            // Access token expired: refresh once and retry.
                            guard let refresh = await keychainClient.load("refresh_token") else { return }
                            if let newAccess = try? await authClient.refreshAccessToken(refresh) {
                                try? await keychainClient.save("access_token", newAccess)
                                try? await syncClient.pull(newAccess)
                            }
                        } catch {
                            // Other errors: skip this cycle; retry on next foreground.
                        }
                        await send(.syncCompleted)
                    }
                )

            case .syncCompleted:
                return .send(.timeline(.onAppear))

            case .ritualDismissed:
                state.showRitual = false
                return .none

            case let .onboarding(.completed(focusDuration)):
                // Apply the user's chosen cycle length and finish onboarding.
                state.timer.focusDuration = focusDuration * 60
                state.onboarding = nil
                return .run { _ in
                    OnboardingStatus.markComplete()
                    telemetry.track(.onboardingCompleted)
                }

            case .onboarding:
                return .none

            case .startCycleRequested:
                // Free-tier gate: allow the cycle, or show the paywall at the wall.
                if PaywallPolicy.canStartCycle(cyclesCompletedToday: state.cyclesCompletedToday, isPro: state.isPro) {
                    return .send(.timer(.startTapped))
                }
                if state.paywall == nil { state.paywall = PaywallFeature.State() }
                return .run { _ in telemetry.track(.paywallShown(reason: "start_blocked")) }

            case let .entitlementsLoaded(isPro):
                state.isPro = isPro
                return .none

            case let .timeline(.loaded(items, _, _)):
                // Track today's completed cycles and trigger the paywall once,
                // when the user reaches the free daily limit (they've felt value).
                state.cyclesCompletedToday = items.count
                if PaywallPolicy.shouldTriggerPaywall(
                    cyclesCompletedToday: items.count,
                    isPro: state.isPro,
                    hasSeenPaywall: state.hasSeenPaywall
                ) {
                    state.hasSeenPaywall = true
                    if state.paywall == nil { state.paywall = PaywallFeature.State() }
                    return .run { _ in telemetry.track(.paywallShown(reason: "daily_limit")) }
                }
                return .none

            case .paywall(.purchaseResult(true)), .paywall(.restoreResult(true)):
                state.isPro = true
                state.paywall = nil
                return .none

            case .paywall:
                return .none

            case .paywallDismissed:
                state.paywall = nil
                return .none

            case let .saveFailed(message):
                state.errorMessage = message
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            default:
                return .none
            }
        }
    }
}
