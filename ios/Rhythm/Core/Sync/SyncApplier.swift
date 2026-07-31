import Foundation
import SwiftData

// Applies a /sync/pull response to local SwiftData: upserts records by id and
// deletes tombstoned ones. This is what makes a change on one device land on
// another. Unknown tables are skipped (forward compatibility with newer clients).
//
// We parse with JSONSerialization rather than Codable because `data` is a
// heterogeneous, table-dependent payload; JSONSerialization preserves number/
// bool fidelity and lets us dispatch on `table` before interpreting `data`.
enum SyncApplier {

    /// Applies the raw pull-response body into `context`. Returns the count of
    /// changes that actually resulted in an upsert or delete.
    @discardableResult
    static func apply(pullResponseData: Data, into context: ModelContext) throws -> Int {
        let root = try JSONSerialization.jsonObject(with: pullResponseData)
        guard let obj = root as? [String: Any],
              let changes = obj["changes"] as? [[String: Any]] else {
            return 0
        }

        var applied = 0
        for change in changes {
            guard let table = change["table"] as? String,
                  let idString = change["id"] as? String,
                  let id = UUID(uuidString: idString) else { continue }
            let deleted = change["deleted_at"] != nil && !(change["deleted_at"] is NSNull)
            let data = change["data"] as? [String: Any] ?? [:]
            if try applyChange(table: table, id: id, deleted: deleted, data: data, into: context) {
                applied += 1
            }
        }
        if applied > 0 {
            try context.save()
        }
        return applied
    }

    /// Returns true if the change resulted in a mutation (upsert or delete).
    private static func applyChange(table: String, id: UUID, deleted: Bool, data: [String: Any], into context: ModelContext) throws -> Bool {
        switch table {
        case SyncTable.cycles:
            let existing = try context.fetch(FetchDescriptor<Cycle>(predicate: #Predicate { $0.id == id })).first
            if deleted {
                if let existing { context.delete(existing) }
                return existing != nil
            }
            let cycle = existing ?? Cycle()
            cycle.id = id
            if let v = data.syncInt("focus_duration") { cycle.focusDuration = v }
            if let v = data.syncBool("ritual_completed") { cycle.ritualCompleted = v }
            if let v = data.syncDate("started_at") { cycle.startedAt = v }
            if let v = data.syncDate("ended_at") { cycle.endedAt = v }
            if existing == nil { context.insert(cycle) }
            return true

        case SyncTable.journalEntries:
            let existing = try context.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })).first
            if deleted {
                if let existing { context.delete(existing) }
                return existing != nil
            }
            let entry = existing ?? JournalEntry(cycleId: UUID(), text: "")
            entry.id = id
            if let v = data.syncString("text") { entry.text = v }
            if let v = data.syncUUID("cycle_id") { entry.cycleId = v }
            if let m = data.syncString("mood") { entry.mood = Mood(rawValue: m) }
            if existing == nil { context.insert(entry) }
            return true

        case SyncTable.hydrationLogs:
            let existing = try context.fetch(FetchDescriptor<HydrationLog>(predicate: #Predicate { $0.id == id })).first
            if deleted {
                if let existing { context.delete(existing) }
                return existing != nil
            }
            let log = existing ?? HydrationLog()
            log.id = id
            if let v = data.syncInt("amount_ml") { log.amountMl = v }
            if let v = data.syncUUID("cycle_id") { log.cycleId = v }
            if existing == nil { context.insert(log) }
            return true

        default:
            return false // unknown table — ignore for forward compatibility
        }
    }

    static func parseDate(_ s: String) -> Date? {
        // Try with and without fractional seconds (the client encodes .iso8601).
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

// Typed accessors over the untyped `data` dictionary. NSNumber bridging is
// handled explicitly so an int field is never misread as a bool and vice versa.
private extension Dictionary where Key == String, Value == Any {
    func syncInt(_ key: String) -> Int? {
        if let n = self[key] as? Int { return n }
        if let n = self[key] as? NSNumber { return n.intValue }
        return nil
    }
    func syncBool(_ key: String) -> Bool? {
        if let b = self[key] as? Bool { return b }
        if let n = self[key] as? NSNumber { return n.boolValue }
        return nil
    }
    func syncString(_ key: String) -> String? { self[key] as? String }
    func syncUUID(_ key: String) -> UUID? { (self[key] as? String).flatMap { UUID(uuidString: $0) } }
    func syncDate(_ key: String) -> Date? { (self[key] as? String).flatMap(SyncApplier.parseDate) }
}
