import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboardingStore)
            } else {
                mainTabs
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.send(.appBecameActive)
            }
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            ),
            presenting: store.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { store.send(.errorDismissed) }
        } message: { message in
            Text(message)
        }
    }

    private var mainTabs: some View {
        TabView {
            TimerView(
                store: store.scope(state: \.timer, action: \.timer),
                onStart: { store.send(.startCycleRequested) }
            )
            .tabItem { Label("Focus", systemImage: "timer") }
            TimelineView(store: store.scope(state: \.timeline, action: \.timeline))
                .tabItem { Label("Timeline", systemImage: "calendar.day.timeline.left") }
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(isPresented: Binding(
            get: { store.showRitual },
            set: { isPresented in if !isPresented { store.send(.ritualDismissed) } }
        )) {
            RitualView(store: store.scope(state: \.ritual, action: \.ritual))
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: Binding(
            get: { store.paywall != nil },
            set: { isPresented in if !isPresented { store.send(.paywallDismissed) } }
        )) {
            if let paywallStore = store.scope(state: \.paywall, action: \.paywall) {
                PaywallView(store: paywallStore)
            }
        }
    }
}
