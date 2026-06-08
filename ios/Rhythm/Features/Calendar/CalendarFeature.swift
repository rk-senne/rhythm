import ComposableArchitecture
import Foundation

@Reducer
struct CalendarFeature {
    @ObservableState
    struct State: Equatable {
        var events: [CalendarEvent] = []
        var suggestedGaps: [FreeGap] = []
        var hasAccess: Bool = false
    }

    enum Action {
        case onAppear
        case accessGranted(Bool)
        case eventsLoaded([CalendarEvent])
        case gapsLoaded([FreeGap])
        case suggestedBlockTapped(FreeGap)
    }

    @Dependency(\.calendarClient) var calendarClient
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let granted = try await calendarClient.requestAccess()
                    await send(.accessGranted(granted))
                }

            case let .accessGranted(granted):
                state.hasAccess = granted
                guard granted else { return .none }
                let today = now
                return .run { send in
                    let start = Calendar.current.startOfDay(for: today)
                    let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
                    let events = try await calendarClient.fetchEvents(start, end)
                    await send(.eventsLoaded(events))
                    let gaps = try await calendarClient.findFreeGaps(today, 45)
                    await send(.gapsLoaded(gaps))
                }

            case let .eventsLoaded(events):
                state.events = events
                return .none

            case let .gapsLoaded(gaps):
                state.suggestedGaps = gaps
                return .none

            case .suggestedBlockTapped:
                return .none // parent handles starting a timer with this time
            }
        }
    }
}
