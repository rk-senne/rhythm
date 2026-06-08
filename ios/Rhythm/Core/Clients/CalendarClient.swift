import EventKit
import Foundation
import ComposableArchitecture

@DependencyClient
struct CalendarClient {
    var requestAccess: @Sendable () async throws -> Bool = { true }
    var fetchEvents: @Sendable (Date, Date) async throws -> [CalendarEvent] = { _, _ in [] }
    var findFreeGaps: @Sendable (Date, Int) async throws -> [FreeGap] = { _, _ in [] }
}

struct CalendarEvent: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}

struct FreeGap: Equatable, Identifiable, Sendable {
    var id: Date { start }
    let start: Date
    let end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

extension CalendarClient: DependencyKey {
    static let liveValue: CalendarClient = {
        let store = EKEventStore()
        return CalendarClient(
            requestAccess: {
                if #available(iOS 17.0, *) {
                    return try await store.requestFullAccessToEvents()
                } else {
                    return try await store.requestAccess(to: .event)
                }
            },
            fetchEvents: { start, end in
                let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
                return store.events(matching: predicate).map {
                    CalendarEvent(id: $0.eventIdentifier, title: $0.title ?? "", startDate: $0.startDate, endDate: $0.endDate)
                }
            },
            findFreeGaps: { date, minMinutes in
                let dayStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
                let dayEnd = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: date)!
                let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
                let events = store.events(matching: predicate)
                    .sorted { $0.startDate < $1.startDate }

                var gaps: [FreeGap] = []
                var cursor = dayStart

                for event in events {
                    if event.startDate > cursor {
                        let gap = FreeGap(start: cursor, end: event.startDate)
                        if gap.duration >= TimeInterval(minMinutes * 60) {
                            gaps.append(gap)
                        }
                    }
                    if event.endDate > cursor { cursor = event.endDate }
                }

                if dayEnd > cursor {
                    let gap = FreeGap(start: cursor, end: dayEnd)
                    if gap.duration >= TimeInterval(minMinutes * 60) {
                        gaps.append(gap)
                    }
                }

                return gaps
            }
        )
    }()
}

extension DependencyValues {
    var calendarClient: CalendarClient {
        get { self[CalendarClient.self] }
        set { self[CalendarClient.self] = newValue }
    }
}
