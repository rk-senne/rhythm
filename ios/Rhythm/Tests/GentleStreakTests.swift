import XCTest
@testable import Rhythm

// Tests for the gentle-streak engine (Core/GentleStreak.swift).
// These were verified green standalone; they run in-project once the app target
// compiles. See docs/RESEARCH_FINDINGS_2026.md rec #2 for the rationale.
final class GentleStreakTests: XCTestCase {

    func testConsecutiveFocusedBuildsStreak() {
        let outcomes: [DayOutcome] = [.focused, .focused, .focused, .focused, .focused]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 5)
        XCTAssertEqual(GentleStreakEngine.longest(from: outcomes), 5)
    }

    func testRestDayPreservesStreak() {
        let outcomes: [DayOutcome] = [.focused, .focused, .rest, .focused]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 3)
    }

    func testGraceAbsorbsASingleMiss() {
        let outcomes: [DayOutcome] = [.focused, .focused, .focused, .missed]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 3)
        let snap = GentleStreakEngine.snapshot(from: outcomes)
        XCTAssertFalse(snap.isActiveToday)
        XCTAssertTrue(snap.atRisk)
    }

    func testSecondConsecutiveMissDecaysGently() {
        let outcomes: [DayOutcome] = [.focused, .focused, .focused, .missed, .missed]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 2)
    }

    func testStreakNeverGoesNegative() {
        let outcomes: [DayOutcome] = [.missed, .missed, .missed, .missed, .missed]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 0)
    }

    func testEarnBackAfterLapse() {
        let outcomes: [DayOutcome] = [.focused, .focused, .focused, .missed, .missed, .focused, .focused]
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 4)
        XCTAssertEqual(GentleStreakEngine.longest(from: outcomes), 4)
    }

    func testRestNotCountedWhenPolicyDisablesIt() {
        let policy = GentleStreakPolicy(graceDays: 1, restCountsAsActive: false, decayPerMissedDay: 1)
        XCTAssertEqual(GentleStreakEngine.current(from: [.focused, .rest], policy: policy), 1)
        XCTAssertEqual(GentleStreakEngine.current(from: [.focused, .rest, .rest], policy: policy), 0)
    }

    func testDailyOutcomesFromDates() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.startOfDay(for: Date(timeIntervalSince1970: 0))
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: start)! }

        let outcomes = GentleStreakEngine.dailyOutcomes(
            focusedDays: [day(0), day(1), day(3)],
            restDays: [day(2)],
            from: day(0), to: day(4), calendar: cal
        )
        XCTAssertEqual(outcomes, [.focused, .focused, .rest, .focused, .missed])
        XCTAssertEqual(GentleStreakEngine.current(from: outcomes), 3)
    }

    func testMessagesAreNonPunitive() {
        let zero = GentleStreakEngine.snapshot(from: [.missed])
        XCTAssertTrue(GentleStreakEngine.message(for: zero).contains("starts with one cycle"))

        let active = GentleStreakEngine.snapshot(from: [.focused, .focused, .focused])
        let msg = GentleStreakEngine.message(for: active)
        XCTAssertTrue(msg.contains("3"))
        for m in [GentleStreakEngine.message(for: zero), msg] {
            XCTAssertFalse(m.lowercased().contains("don't lose"))
            XCTAssertFalse(m.lowercased().contains("broke"))
        }
    }

    func testSnapshotLongestReflectsPeak() {
        let outcomes: [DayOutcome] = [.focused, .focused, .focused, .focused, .missed, .missed, .missed]
        let snap = GentleStreakEngine.snapshot(from: outcomes)
        XCTAssertEqual(snap.longest, 4)
        XCTAssertLessThan(snap.current, snap.longest)
    }
}
