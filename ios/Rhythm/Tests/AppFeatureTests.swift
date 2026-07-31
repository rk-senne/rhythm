import ComposableArchitecture
import XCTest
@testable import Rhythm

/// Minimal thread-safe box for capturing test-double side effects without
/// depending on ConcurrencyExtras' LockIsolated directly.
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

@MainActor
final class AppFeatureTests: XCTestCase {

    func testOnboardingCompletionAppliesDurationAndClears() async {
        let store = TestStore(
            initialState: AppFeature.State(onboarding: OnboardingFeature.State())
        ) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.onboarding(.completed(focusDuration: 60)))

        XCTAssertNil(store.state.onboarding)                 // onboarding dismissed
        XCTAssertEqual(store.state.timer.focusDuration, 3600) // 60 min applied (seconds)
        XCTAssertTrue(OnboardingStatus.isComplete)            // persisted
    }

    func testRitualDismissedClosesSheet() async {
        let store = TestStore(initialState: AppFeature.State(showRitual: true)) {
            AppFeature()
        }
        await store.send(.ritualDismissed) {
            $0.showRitual = false
        }
    }

    func testRitualCompletedSavesCycleAndLogsWater() async {
        let savedCycle = Box(false)
        let savedJournal = Box<String?>(nil)
        let loggedWater = Box(0)

        var initial = AppFeature.State()
        initial.showRitual = true
        initial.currentCycleId = UUID()
        initial.ritual.hydrated = true
        initial.ritual.journalText = "deep flow"

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dataClient.saveCycle = { _, _, _ in savedCycle.value = true }
            $0.dataClient.saveJournal = { _, _, text, _ in savedJournal.value = text }
            $0.dataClient.saveHydration = { _, _, _ in }
            $0.dataClient.fetchRecentCycles = { _ in [] }
            $0.healthKitClient.logWaterIntake = { ml in loggedWater.value = ml }
            $0.keychainClient.load = { _ in nil } // signed out -> no push on this path
        }
        store.exhaustivity = .off

        await store.send(.ritual(.completed))
        await store.receive(\.cycleSaved)
        await store.skipReceivedActions() // drain the timeline refresh chain

        XCTAssertFalse(store.state.showRitual)
        XCTAssertTrue(savedCycle.value, "cycle should be persisted")
        XCTAssertEqual(savedJournal.value, "deep flow", "journal text should be saved")
        XCTAssertEqual(loggedWater.value, 250, "hydration should mirror to HealthKit")
    }

    func testRitualCompletedPushesCycleWhenSignedIn() async {
        let pushedTable = Box<String?>(nil)
        let pushedToken = Box<String?>(nil)

        var initial = AppFeature.State()
        initial.showRitual = true
        initial.currentCycleId = UUID()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dataClient.saveCycle = { _, _, _ in }
            $0.dataClient.saveJournal = { _, _, _, _ in }
            $0.dataClient.saveHydration = { _, _, _ in }
            $0.dataClient.fetchRecentCycles = { _ in [] }
            $0.healthKitClient.logWaterIntake = { _ in }
            $0.keychainClient.load = { _ in "access-token" } // signed in -> should push
            $0.syncClient.pushChanges = { changes, token in
                pushedTable.value = changes.first?.table
                pushedToken.value = token
            }
        }
        store.exhaustivity = .off

        await store.send(.ritual(.completed))
        await store.receive(\.cycleSaved)
        await store.skipReceivedActions()

        XCTAssertEqual(pushedTable.value, "cycles", "a cycles change should be pushed")
        XCTAssertEqual(pushedToken.value, "access-token")
    }

    func testRitualCompletedPushesAllEntities() async {
        let pushedTables = Box<[String]>([])

        var initial = AppFeature.State()
        initial.showRitual = true
        initial.currentCycleId = UUID()
        initial.ritual.journalText = "deep flow"
        initial.ritual.hydrated = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dataClient.saveCycle = { _, _, _ in }
            $0.dataClient.saveJournal = { _, _, _, _ in }
            $0.dataClient.saveHydration = { _, _, _ in }
            $0.dataClient.fetchRecentCycles = { _ in [] }
            $0.healthKitClient.logWaterIntake = { _ in }
            $0.keychainClient.load = { _ in "access-token" }
            $0.syncClient.pushChanges = { changes, _ in
                pushedTables.value = changes.map(\.table)
            }
        }
        store.exhaustivity = .off

        await store.send(.ritual(.completed))
        await store.receive(\.cycleSaved)
        await store.skipReceivedActions()

        XCTAssertEqual(pushedTables.value, ["cycles", "journal_entries", "hydration_logs"],
                       "cycle + journal + hydration should all be pushed")
    }

    func testCycleSaveFailureSurfacesError() async {
        struct SaveError: Error {}

        var initial = AppFeature.State()
        initial.showRitual = true
        initial.currentCycleId = UUID()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dataClient.saveCycle = { _, _, _ in throw SaveError() }
        }
        store.exhaustivity = .off

        await store.send(.ritual(.completed))
        await store.receive(\.saveFailed)

        XCTAssertNotNil(store.state.errorMessage, "a failed save should surface a user-facing error")
    }

    func testStartCycleBlockedAtFreeLimitShowsPaywall() async {
        var initial = AppFeature.State()
        initial.cyclesCompletedToday = FreeTier.dailyCycleLimit
        initial.isPro = false

        let store = TestStore(initialState: initial) { AppFeature() }
        store.exhaustivity = .off

        await store.send(.startCycleRequested)

        XCTAssertNotNil(store.state.paywall, "hitting the free daily limit should show the paywall")
        XCTAssertFalse(store.state.timer.isRunning, "the timer must not start when the free limit is reached")
    }

    func testTimelineLoadTriggersPaywallAtLimit() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
        store.exhaustivity = .off

        let items = (0..<FreeTier.dailyCycleLimit).map { _ in
            TimelineFeature.CycleItem(id: UUID(), startedAt: Date(), duration: 5400, ritualCompleted: true)
        }
        let streak = GentleStreak(current: 1, longest: 1, isActiveToday: true, atRisk: false)

        await store.send(.timeline(.loaded(items, streak, "msg")))

        XCTAssertNotNil(store.state.paywall, "reaching the daily limit should trigger the paywall")
        XCTAssertTrue(store.state.hasSeenPaywall)
        XCTAssertEqual(store.state.cyclesCompletedToday, FreeTier.dailyCycleLimit)
    }

    func testTimelineLoadUnderLimitDoesNotTriggerPaywall() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
        store.exhaustivity = .off

        let items = [TimelineFeature.CycleItem(id: UUID(), startedAt: Date(), duration: 5400, ritualCompleted: true)]
        let streak = GentleStreak(current: 1, longest: 1, isActiveToday: true, atRisk: false)

        await store.send(.timeline(.loaded(items, streak, "")))

        XCTAssertNil(store.state.paywall, "one cycle is under the free limit — no paywall")
        XCTAssertEqual(store.state.cyclesCompletedToday, 1)
    }

    func testPaywallTriggerTracksTelemetry() async {
        let events = Box<[String]>([])
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.telemetry.track = { event in events.value.append(event.name) }
        }
        store.exhaustivity = .off

        let items = (0..<FreeTier.dailyCycleLimit).map { _ in
            TimelineFeature.CycleItem(id: UUID(), startedAt: Date(), duration: 5400, ritualCompleted: true)
        }
        let streak = GentleStreak(current: 1, longest: 1, isActiveToday: true, atRisk: false)

        await store.send(.timeline(.loaded(items, streak, "")))
        await store.finish()

        XCTAssertTrue(events.value.contains("paywall_shown"), "reaching the daily limit should emit paywall_shown")
    }
}
