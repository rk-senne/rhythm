import ComposableArchitecture

@Reducer
struct RitualFeature {
    enum Step: Equatable { case breathe, hydrate, journal, complete }

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .breathe
        var hydrated: Bool = false
        var journalText: String = ""
    }

    enum Action {
        case nextStep
        case hydrateToggled
        case journalTextChanged(String)
        case completed
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextStep:
                switch state.currentStep {
                case .breathe: state.currentStep = .hydrate
                case .hydrate: state.currentStep = .journal
                case .journal: state.currentStep = .complete
                case .complete: break
                }
                return state.currentStep == .complete ? .send(.completed) : .none
            case .hydrateToggled:
                state.hydrated.toggle()
                return .none
            case let .journalTextChanged(text):
                state.journalText = text
                return .none
            case .completed:
                return .none
            }
        }
    }
}
