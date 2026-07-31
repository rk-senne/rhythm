import ComposableArchitecture
import XCTest
@testable import Rhythm

@MainActor
final class TimerFeatureTests: XCTestCase {

    func testStartRunsTicksThenFinishes() async {
        let store = TestStore(initialState: TimerFeature.State(focusDuration: 3)) {
            TimerFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
            // Best-effort side effects — no-ops in the test.
            $0.liveActivityClient.start = { _ in }
            $0.liveActivityClient.stop = {}
            $0.focusModeClient.enable = {}
            $0.focusModeClient.disable = {}
            $0.notificationClient.requestAuthorization = { true }
            $0.notificationClient.scheduleRitualReminder = { _ in }
            // Deterministic countdown stream.
            $0.timerClient.start = { _ in
                AsyncStream { c in
                    c.yield(2); c.yield(1); c.yield(0); c.finish()
                }
            }
        }

        await store.send(.startTapped) {
            $0.isRunning = true
            $0.secondsRemaining = 3
            $0.startedAt = Date(timeIntervalSince1970: 1000)
        }
        await store.receive(\.timerTick) { $0.secondsRemaining = 2 }
        await store.receive(\.timerTick) { $0.secondsRemaining = 1 }
        await store.receive(\.timerTick) { $0.secondsRemaining = 0 }
        await store.receive(\.timerFinished) { $0.isRunning = false }
    }

    func testStopResetsRunningState() async {
        var initial = TimerFeature.State()
        initial.isRunning = true
        initial.startedAt = Date(timeIntervalSince1970: 500)

        let store = TestStore(initialState: initial) {
            TimerFeature()
        } withDependencies: {
            $0.liveActivityClient.stop = {}
            $0.focusModeClient.disable = {}
        }

        await store.send(.stopTapped) {
            $0.isRunning = false
            $0.startedAt = nil
        }
    }
}
