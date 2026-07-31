import XCTest
import SwiftData
@testable import Rhythm

@MainActor
final class SyncApplierTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Cycle.self, JournalEntry.self, HydrationLog.self, UserSettings.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func cycleJSON(_ id: UUID, focus: Int, ritual: Bool, deleted: Bool = false) -> Data {
        let del = deleted ? #","deleted_at":"2026-07-31T11:00:00Z""# : ""
        return """
        {"changes":[{"table":"cycles","id":"\(id.uuidString)","data":{"focus_duration":\(focus),"ritual_completed":\(ritual),"started_at":"2026-07-31T10:00:00Z"},"updated_at":"2026-07-31T10:00:00Z"\(del),"server_updated_at":"2026-07-31T10:00:00Z"}]}
        """.data(using: .utf8)!
    }

    func testApplyInsertsCycle() throws {
        let ctx = try makeContext()
        let id = UUID()
        let n = try SyncApplier.apply(pullResponseData: cycleJSON(id, focus: 5400, ritual: true), into: ctx)
        XCTAssertEqual(n, 1)

        let cycles = try ctx.fetch(FetchDescriptor<Cycle>())
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.id, id)
        XCTAssertEqual(cycles.first?.focusDuration, 5400)
        XCTAssertEqual(cycles.first?.ritualCompleted, true)
    }

    func testApplyUpsertsInsteadOfDuplicating() throws {
        let ctx = try makeContext()
        let id = UUID()
        _ = try SyncApplier.apply(pullResponseData: cycleJSON(id, focus: 3600, ritual: false), into: ctx)
        _ = try SyncApplier.apply(pullResponseData: cycleJSON(id, focus: 5400, ritual: true), into: ctx)

        let cycles = try ctx.fetch(FetchDescriptor<Cycle>())
        XCTAssertEqual(cycles.count, 1, "same id must update in place, not duplicate")
        XCTAssertEqual(cycles.first?.focusDuration, 5400)
        XCTAssertEqual(cycles.first?.ritualCompleted, true)
    }

    func testApplyDeletesTombstone() throws {
        let ctx = try makeContext()
        let id = UUID()
        _ = try SyncApplier.apply(pullResponseData: cycleJSON(id, focus: 5400, ritual: true), into: ctx)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Cycle>()).count, 1)

        let n = try SyncApplier.apply(pullResponseData: cycleJSON(id, focus: 0, ritual: false, deleted: true), into: ctx)
        XCTAssertEqual(n, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Cycle>()).count, 0, "a tombstone should delete the record")
    }

    func testApplyJournalEntry() throws {
        let ctx = try makeContext()
        let id = UUID()
        let cycleId = UUID()
        let json = """
        {"changes":[{"table":"journal_entries","id":"\(id.uuidString)","data":{"text":"deep flow","mood":"good","cycle_id":"\(cycleId.uuidString)"},"updated_at":"2026-07-31T10:00:00Z","server_updated_at":"2026-07-31T10:00:00Z"}]}
        """.data(using: .utf8)!

        _ = try SyncApplier.apply(pullResponseData: json, into: ctx)
        let entries = try ctx.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "deep flow")
        XCTAssertEqual(entries.first?.mood, .good)
        XCTAssertEqual(entries.first?.cycleId, cycleId)
    }

    func testApplyIgnoresUnknownTableAndInvalidId() throws {
        let ctx = try makeContext()

        // Unknown table with a valid UUID -> not applied (forward-compat skip).
        let unknown = """
        {"changes":[{"table":"widgets","id":"\(UUID().uuidString)","data":{}}]}
        """.data(using: .utf8)!
        XCTAssertEqual(try SyncApplier.apply(pullResponseData: unknown, into: ctx), 0)

        // Invalid UUID id -> skipped.
        let badID = #"{"changes":[{"table":"cycles","id":"not-a-uuid","data":{}}]}"#.data(using: .utf8)!
        XCTAssertEqual(try SyncApplier.apply(pullResponseData: badID, into: ctx), 0)

        // Empty change set.
        XCTAssertEqual(try SyncApplier.apply(pullResponseData: #"{"changes":[]}"#.data(using: .utf8)!, into: ctx), 0)
    }
}
