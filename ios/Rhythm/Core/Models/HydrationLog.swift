import Foundation
import SwiftData

@Model
final class HydrationLog {
    var id: UUID
    var cycleId: UUID?
    var amountMl: Int
    var createdAt: Date

    init(amountMl: Int = 250, cycleId: UUID? = nil) {
        self.id = UUID()
        self.cycleId = cycleId
        self.amountMl = amountMl
        self.createdAt = .now
    }
}
