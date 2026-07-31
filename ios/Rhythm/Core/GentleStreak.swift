import Foundation

// MARK: - Gentle Streaks
//
// Research-driven enhancement (see docs/RESEARCH_FINDINGS_2026.md, rec #2).
//
// Punitive streaks that reset to zero after a single missed day are the wrong
// fit for Rhythm's "calm productivity" brand and are actively harmful to the
// ADHD-optimizer persona. Category leaders (Duolingo's streak-repair, Gentler
// Streak's rest-inclusive model) show that *forgiving* streaks retain better.
//
// GentleStreak encodes those calm rules as a pure, dependency-free value type
// (Foundation only) so it can be unit-tested in isolation and dropped into any
// target (app, Watch, widget) without pulling in TCA/SwiftUI:
//
//   • an intentional REST day preserves the streak (rest is part of the rhythm),
//   • a GRACE window absorbs the occasional missed day with no penalty,
//   • lapses beyond grace DECAY the streak gradually — never a hard reset to 0,
//   • the streak can be EARNED BACK through effort after a lapse.

/// What happened on a single day, from the streak's point of view.
public enum DayOutcome: Equatable {
    /// The user completed at least one focus cycle.
    case focused
    /// The user intentionally marked a rest day (counts as staying in rhythm).
    case rest
    /// Nothing was logged.
    case missed
}

/// Tunable rules for how forgiving the streak is. `.calm` is the brand default.
public struct GentleStreakPolicy: Equatable {
    /// Number of consecutive missed days tolerated before any decay begins.
    public var graceDays: Int
    /// Whether an intentional rest day preserves the streak.
    public var restCountsAsActive: Bool
    /// How much the streak decays per missed day *after* the grace window.
    public var decayPerMissedDay: Int

    public init(graceDays: Int, restCountsAsActive: Bool, decayPerMissedDay: Int) {
        self.graceDays = graceDays
        self.restCountsAsActive = restCountsAsActive
        self.decayPerMissedDay = decayPerMissedDay
    }

    /// The calm default: one free grace day, rest days count, gentle 1/day decay.
    public static let calm = GentleStreakPolicy(
        graceDays: 1,
        restCountsAsActive: true,
        decayPerMissedDay: 1
    )
}

/// A computed streak result plus the context needed to render gentle UI copy.
public struct GentleStreak: Equatable {
    /// The current streak length (never negative).
    public let current: Int
    /// The longest streak ever reached in the supplied history.
    public let longest: Int
    /// True if today's outcome kept the streak alive (focused or rest).
    public let isActiveToday: Bool
    /// True if the streak is one missed day away from starting to decay.
    public let atRisk: Bool

    public init(current: Int, longest: Int, isActiveToday: Bool, atRisk: Bool) {
        self.current = current
        self.longest = longest
        self.isActiveToday = isActiveToday
        self.atRisk = atRisk
    }
}

public enum GentleStreakEngine {

    /// Computes the current streak from a chronologically ordered list of daily
    /// outcomes (oldest first) under the given policy.
    public static func current(from outcomes: [DayOutcome], policy: GentleStreakPolicy = .calm) -> Int {
        var streak = 0
        var missedRun = 0
        for outcome in outcomes {
            switch outcome {
            case .focused:
                streak += 1
                missedRun = 0
            case .rest:
                if !policy.restCountsAsActive {
                    // Treat rest like a miss if the policy disables rest credit.
                    missedRun += 1
                    if missedRun > policy.graceDays {
                        streak = max(0, streak - policy.decayPerMissedDay)
                    }
                } else {
                    missedRun = 0
                }
            case .missed:
                missedRun += 1
                if missedRun > policy.graceDays {
                    streak = max(0, streak - policy.decayPerMissedDay)
                }
            }
        }
        return streak
    }

    /// The longest streak reached at any point across the history.
    public static func longest(from outcomes: [DayOutcome], policy: GentleStreakPolicy = .calm) -> Int {
        var streak = 0
        var missedRun = 0
        var best = 0
        for outcome in outcomes {
            switch outcome {
            case .focused:
                streak += 1
                missedRun = 0
            case .rest:
                if !policy.restCountsAsActive {
                    missedRun += 1
                    if missedRun > policy.graceDays {
                        streak = max(0, streak - policy.decayPerMissedDay)
                    }
                } else {
                    missedRun = 0
                }
            case .missed:
                missedRun += 1
                if missedRun > policy.graceDays {
                    streak = max(0, streak - policy.decayPerMissedDay)
                }
            }
            best = max(best, streak)
        }
        return best
    }

    /// Builds a full snapshot (current, longest, today status, at-risk flag).
    public static func snapshot(from outcomes: [DayOutcome], policy: GentleStreakPolicy = .calm) -> GentleStreak {
        let cur = current(from: outcomes, policy: policy)
        let best = max(cur, longest(from: outcomes, policy: policy))
        let today = outcomes.last
        let isActiveToday = today == .focused || (policy.restCountsAsActive && today == .rest)
        // At risk when today was missed but we're still inside the grace window
        // (i.e. the streak hasn't decayed yet but will if tomorrow is missed too).
        let atRisk = !isActiveToday && cur > 0 && trailingMissed(outcomes) <= policy.graceDays
        return GentleStreak(current: cur, longest: best, isActiveToday: isActiveToday, atRisk: atRisk)
    }

    /// Converts day-normalized activity into an ordered outcome list across a
    /// closed day range. `focusedDays` and `restDays` should contain dates
    /// normalized to the start of day in `calendar`.
    public static func dailyOutcomes(
        focusedDays: Set<Date>,
        restDays: Set<Date>,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DayOutcome] {
        var outcomes: [DayOutcome] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            if focusedDays.contains(day) {
                outcomes.append(.focused)
            } else if restDays.contains(day) {
                outcomes.append(.rest)
            } else {
                outcomes.append(.missed)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return outcomes
    }

    /// Gentle, non-punitive UI copy for a snapshot. Never guilt-trips the user.
    public static func message(for streak: GentleStreak) -> String {
        switch (streak.current, streak.isActiveToday, streak.atRisk) {
        case (0, _, _):
            return "Every rhythm starts with one cycle. Begin when you're ready."
        case (let n, true, _):
            return "\(n) \(n == 1 ? "day" : "days") of intentional rhythm. Nicely done."
        case (let n, false, true):
            return "Your \(n)-day rhythm is paused, not lost. A rest day keeps it going."
        default:
            return "\(streak.current)-day rhythm. Pick back up whenever suits you."
        }
    }

    private static func trailingMissed(_ outcomes: [DayOutcome]) -> Int {
        var count = 0
        for outcome in outcomes.reversed() {
            if outcome == .missed { count += 1 } else { break }
        }
        return count
    }
}
