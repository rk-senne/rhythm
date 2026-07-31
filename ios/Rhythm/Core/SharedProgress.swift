import Foundation

// Shared between the app (writer) and the widget/watch (readers) via the App
// Group container. This file is a member of BOTH the app and widget targets in
// project.yml, so each target compiles its own copy; data crosses the boundary
// as JSON in the shared UserDefaults suite.
//
// Fixes the widget "TODO: read from App Group shared container" — widgets now
// show live cycle progress instead of hard-coded zeros.

let rhythmAppGroupID = "group.com.rhythm.app"

/// A snapshot of today's progress, small enough to live in shared defaults.
struct RhythmProgress: Codable, Equatable {
    var date: Date // start-of-day this snapshot represents
    var cyclesCompleted: Int
    var cyclesGoal: Int
    var streakCurrent: Int

    static let empty = RhythmProgress(
        date: .distantPast, cyclesCompleted: 0, cyclesGoal: 4, streakCurrent: 0
    )
}

enum SharedProgressStore {
    private static let key = "rhythm.progress.today"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: rhythmAppGroupID)
    }

    /// Persist the latest progress snapshot for widgets to read.
    static func write(_ progress: RhythmProgress) {
        guard let defaults, let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: key)
    }

    /// Read today's progress. If the stored snapshot is from a previous day,
    /// the completed count resets to 0 (a new day) while goal/streak carry over.
    static func read(calendar: Calendar = .current, now: Date = .now) -> RhythmProgress {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(RhythmProgress.self, from: data)
        else {
            return .empty
        }
        if !calendar.isDate(stored.date, inSameDayAs: now) {
            return RhythmProgress(
                date: calendar.startOfDay(for: now),
                cyclesCompleted: 0,
                cyclesGoal: stored.cyclesGoal,
                streakCurrent: stored.streakCurrent
            )
        }
        return stored
    }
}
