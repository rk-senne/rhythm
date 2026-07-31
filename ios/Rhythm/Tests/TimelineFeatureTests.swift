import ComposableArchitecture
import XCTest
@testable import Rhythm

@MainActor
final class TimelineFeatureTests: XCTestCase {

    func testOnAppearWithNoCyclesShowsGentleZeroState() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.dataClient.fetchRecentCycles = { _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        XCTAssertEqual(store.state.cycles.count, 0)
        XCTAssertEqual(store.state.streak.current, 0)
        XCTAssertFalse(store.state.streak.isActiveToday)
        // Non-punitive copy for a fresh user.
        XCTAssertTrue(store.state.streakMessage.contains("starts with one cycle"))
    }

    func testOnAppearWithCyclesTodayComputesActiveStreak() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            // Build cycles inside the closure to avoid capturing non-Sendable @Model.
            $0.dataClient.fetchRecentCycles = { _ in
                let c1 = Cycle(focusDuration: 5400); c1.startedAt = .now; c1.ritualCompleted = true
                let c2 = Cycle(focusDuration: 3600); c2.startedAt = .now
                return [c1, c2]
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        // Two cycles today => today's list has 2, and it's one day of rhythm.
        XCTAssertEqual(store.state.cycles.count, 2)
        XCTAssertEqual(store.state.streak.current, 1)
        XCTAssertEqual(store.state.streak.longest, 1)
        XCTAssertTrue(store.state.streak.isActiveToday)
        XCTAssertTrue(store.state.streakMessage.contains("1 day"))
    }
}
