import Foundation
import SwiftData
import ComposableArchitecture

@DependencyClient
struct DataClient {
    var saveCycle: @Sendable (UUID, Int, Bool) async throws -> Void = { _, _, _ in }
    var saveJournal: @Sendable (UUID, UUID, String, Mood?) async throws -> Void = { _, _, _, _ in }
    var saveHydration: @Sendable (UUID, UUID, Int) async throws -> Void = { _, _, _ in }
    var fetchTodayCycles: @Sendable () async throws -> [Cycle] = { [] }
    var fetchRecentCycles: @Sendable (Int) async throws -> [Cycle] = { _ in [] }
}

extension DataClient: DependencyKey {
    static let liveValue = DataClient(
        saveCycle: { id, duration, ritualCompleted in
            let cycle = Cycle(focusDuration: duration)
            cycle.id = id
            cycle.endedAt = .now
            cycle.ritualCompleted = ritualCompleted
            try await DataStore.shared.save(cycle)
        },
        saveJournal: { id, cycleId, text, mood in
            let entry = JournalEntry(cycleId: cycleId, text: text, mood: mood)
            entry.id = id
            try await DataStore.shared.save(entry)
        },
        saveHydration: { id, cycleId, amountMl in
            let log = HydrationLog(amountMl: amountMl, cycleId: cycleId)
            log.id = id
            try await DataStore.shared.save(log)
        },
        fetchTodayCycles: {
            try await DataStore.shared.fetchTodayCycles()
        },
        fetchRecentCycles: { days in
            try await DataStore.shared.fetchRecentCycles(days: days)
        }
    )
}

extension DependencyValues {
    var dataClient: DataClient {
        get { self[DataClient.self] }
        set { self[DataClient.self] = newValue }
    }
}

@ModelActor
actor DataStore {
    static let shared = DataStore(modelContainer: try! ModelContainer(for: Cycle.self, JournalEntry.self, HydrationLog.self, UserSettings.self))

    func save(_ model: some PersistentModel) throws {
        modelContext.insert(model)
        try modelContext.save()
    }

    func fetchTodayCycles() throws -> [Cycle] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<Cycle> { $0.startedAt >= startOfDay }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt)])
        return try modelContext.fetch(descriptor)
    }

    func fetchRecentCycles(days: Int) throws -> [Cycle] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: .now)) ?? .now
        let predicate = #Predicate<Cycle> { $0.startedAt >= cutoff }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt)])
        return try modelContext.fetch(descriptor)
    }

    /// Applies a /sync/pull response body into the local store (upsert + delete).
    @discardableResult
    func applyPulledChanges(_ responseData: Data) throws -> Int {
        try SyncApplier.apply(pullResponseData: responseData, into: modelContext)
    }

    func loadSettings() throws -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        return try modelContext.fetch(descriptor).first
    }

    func saveSettings(_ settings: UserSettings) throws {
        // Delete existing, insert new
        let existing = try modelContext.fetch(FetchDescriptor<UserSettings>())
        existing.forEach { modelContext.delete($0) }
        modelContext.insert(settings)
        try modelContext.save()
    }
}
