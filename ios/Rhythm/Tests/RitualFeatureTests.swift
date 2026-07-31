import ComposableArchitecture
import XCTest
@testable import Rhythm

@MainActor
final class RitualFeatureTests: XCTestCase {

    func testStepsAdvanceBreatheToComplete() async {
        let store = TestStore(initialState: RitualFeature.State()) { RitualFeature() }

        await store.send(.nextStep) { $0.currentStep = .hydrate }
        await store.send(.nextStep) { $0.currentStep = .journal }
        await store.send(.nextStep) { $0.currentStep = .complete }
        await store.receive(\.completed) // reaching .complete emits .completed
    }

    func testHydrateToggles() async {
        let store = TestStore(initialState: RitualFeature.State()) { RitualFeature() }
        await store.send(.hydrateToggled) { $0.hydrated = true }
        await store.send(.hydrateToggled) { $0.hydrated = false }
    }

    func testJournalTextChange() async {
        let store = TestStore(initialState: RitualFeature.State()) { RitualFeature() }
        await store.send(.journalTextChanged("deep flow")) { $0.journalText = "deep flow" }
    }

    func testMoodSelectionAndClear() async {
        let store = TestStore(initialState: RitualFeature.State()) { RitualFeature() }
        await store.send(.moodSelected(.good)) { $0.mood = .good }
        await store.send(.moodSelected(nil)) { $0.mood = nil } // tapping again clears it
    }
}
