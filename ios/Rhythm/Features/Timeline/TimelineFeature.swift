import ComposableArchitecture
import Foundation
import WidgetKit

@Reducer
struct TimelineFeature {
    @ObservableState
    struct State: Equatable {
        var cycles: [CycleItem] = []
        var streak = GentleStreak(current: 0, longest: 0, isActiveToday: false, atRisk: false)
        var streakMessage: String = ""
    }

    struct CycleItem: Equatable, Identifiable {
        let id: UUID
        let startedAt: Date
        let duration: Int
        let ritualCompleted: Bool
    }

    enum Action {
        case onAppear
        case loaded([CycleItem], GentleStreak, String)
    }

    @Dependency(\.dataClient) var dataClient

    // How many days of history to consider when computing the gentle streak.
    private let streakWindowDays = 30

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let window = streakWindowDays
                return .run { send in
                    let recent = try await dataClient.fetchRecentCycles(window)
                    let cal = Calendar.current

                    let items = recent
                        .filter { cal.isDate($0.startedAt, inSameDayAs: .now) }
                        .map {
                            CycleItem(
                                id: $0.id,
                                startedAt: $0.startedAt,
                                duration: $0.focusDuration,
                                ritualCompleted: $0.ritualCompleted
                            )
                        }
                        .sorted { $0.startedAt < $1.startedAt }

                    // A day counts as "focused" if it has at least one cycle.
                    let focusedDays = Set(recent.map { cal.startOfDay(for: $0.startedAt) })
                    let today = cal.startOfDay(for: .now)
                    let start = cal.date(byAdding: .day, value: -(window - 1), to: today) ?? today
                    let outcomes = GentleStreakEngine.dailyOutcomes(
                        focusedDays: focusedDays,
                        restDays: [],
                        from: start,
                        to: today,
                        calendar: cal
                    )
                    let streak = GentleStreakEngine.snapshot(from: outcomes)
                    let message = GentleStreakEngine.message(for: streak)

                    // Publish today's progress to the App Group so widgets update.
                    SharedProgressStore.write(RhythmProgress(
                        date: today,
                        cyclesCompleted: items.count,
                        cyclesGoal: 4,
                        streakCurrent: streak.current
                    ))
                    WidgetCenter.shared.reloadAllTimelines()

                    await send(.loaded(items, streak, message))
                }

            case let .loaded(items, streak, message):
                state.cycles = items
                state.streak = streak
                state.streakMessage = message
                return .none
            }
        }
    }
}
