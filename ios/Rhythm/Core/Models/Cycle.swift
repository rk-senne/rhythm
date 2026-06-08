import Foundation
import SwiftData

@Model
final class Cycle {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var focusDuration: Int // seconds
    var ritualCompleted: Bool
    var createdAt: Date

    init(focusDuration: Int = 5400) {
        self.id = UUID()
        self.startedAt = .now
        self.focusDuration = focusDuration
        self.ritualCompleted = false
        self.createdAt = .now
    }
}
