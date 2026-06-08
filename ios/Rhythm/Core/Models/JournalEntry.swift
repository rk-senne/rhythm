import Foundation
import SwiftData

enum Mood: String, Codable, CaseIterable {
    case great, good, neutral, low, rough
}

@Model
final class JournalEntry {
    var id: UUID
    var cycleId: UUID
    var text: String
    var mood: Mood?
    var createdAt: Date

    init(cycleId: UUID, text: String, mood: Mood? = nil) {
        self.id = UUID()
        self.cycleId = cycleId
        self.text = text
        self.mood = mood
        self.createdAt = .now
    }
}
