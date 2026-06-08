import ComposableArchitecture
import Foundation

@Reducer
struct TimelineFeature {
    @ObservableState
    struct State: Equatable {
        var cycles: [CycleItem] = []
    }

    struct CycleItem: Equatable, Identifiable {
        let id: UUID
        let startedAt: Date
        let duration: Int
        let ritualCompleted: Bool
    }

    enum Action {
        case onAppear
        case cyclesLoaded([CycleItem])
    }

    @Dependency(\.dataClient) var dataClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let cycles = try await dataClient.fetchTodayCycles()
                    let items = cycles.map {
                        CycleItem(id: $0.id, startedAt: $0.startedAt, duration: $0.focusDuration, ritualCompleted: $0.ritualCompleted)
                    }
                    await send(.cyclesLoaded(items))
                }
            case let .cyclesLoaded(cycles):
                state.cycles = cycles
                return .none
            }
        }
    }
}
