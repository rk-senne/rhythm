import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var focusDurationMinutes: Int
    var dailyHydrationGoalMl: Int
    var enableFocusMode: Bool
    var enableSoundAlerts: Bool

    init() {
        self.id = UUID()
        self.focusDurationMinutes = 90
        self.dailyHydrationGoalMl = 2000
        self.enableFocusMode = true
        self.enableSoundAlerts = true
    }
}
