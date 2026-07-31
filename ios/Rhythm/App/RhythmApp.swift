import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct RhythmApp: App {
    let store = Store(
        initialState: AppFeature.State(
            onboarding: OnboardingStatus.isComplete ? nil : OnboardingFeature.State()
        )
    ) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .modelContainer(for: [Cycle.self, JournalEntry.self, HydrationLog.self, UserSettings.self])
    }
}
