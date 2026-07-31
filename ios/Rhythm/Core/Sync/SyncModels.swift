import Foundation

// The symmetric wire contract for a synced record's `data` payload. The same
// snake_case field names are written on push (these DTOs) and read on apply
// (SyncApplier), and they match the backend's opaque JSONB `data` column.

enum SyncTable {
    static let cycles = "cycles"
    static let journalEntries = "journal_entries"
    static let hydrationLogs = "hydration_logs"
}

/// `data` payload for a Cycle record.
struct CycleData: Encodable {
    let startedAt: Date
    let endedAt: Date?
    let focusDuration: Int
    let ritualCompleted: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case focusDuration = "focus_duration"
        case ritualCompleted = "ritual_completed"
        case createdAt = "created_at"
    }
}

/// `data` payload for a JournalEntry record.
struct JournalData: Encodable {
    let text: String
    let mood: String?
    let cycleId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case text, mood
        case cycleId = "cycle_id"
        case createdAt = "created_at"
    }
}

/// `data` payload for a HydrationLog record.
struct HydrationData: Encodable {
    let amountMl: Int
    let cycleId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case amountMl = "amount_ml"
        case cycleId = "cycle_id"
        case createdAt = "created_at"
    }
}

/// Builds the outbound `SyncChange`s for local mutations that should be pushed.
enum SyncPayloads {
    static func cycleChange(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        focusDuration: Int,
        ritualCompleted: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) -> SyncChange {
        SyncChange(
            table: SyncTable.cycles,
            id: id.uuidString,
            data: CycleData(
                startedAt: startedAt,
                endedAt: endedAt,
                focusDuration: focusDuration,
                ritualCompleted: ritualCompleted,
                createdAt: createdAt
            ),
            updatedAt: updatedAt
        )
    }

    static func journalChange(
        id: UUID,
        cycleId: UUID,
        text: String,
        mood: Mood?,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) -> SyncChange {
        SyncChange(
            table: SyncTable.journalEntries,
            id: id.uuidString,
            data: JournalData(text: text, mood: mood?.rawValue, cycleId: cycleId, createdAt: createdAt),
            updatedAt: updatedAt
        )
    }

    static func hydrationChange(
        id: UUID,
        cycleId: UUID,
        amountMl: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) -> SyncChange {
        SyncChange(
            table: SyncTable.hydrationLogs,
            id: id.uuidString,
            data: HydrationData(amountMl: amountMl, cycleId: cycleId, createdAt: createdAt),
            updatedAt: updatedAt
        )
    }
}
