import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        TabView {
            TimerView(store: store.scope(state: \.timer, action: \.timer))
                .tabItem { Label("Focus", systemImage: "timer") }
            TimelineView(store: store.scope(state: \.timeline, action: \.timeline))
                .tabItem { Label("Timeline", systemImage: "calendar.day.timeline.left") }
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(isPresented: $store.showRitual) {
            RitualView(store: store.scope(state: \.ritual, action: \.ritual))
                .interactiveDismissDisabled()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.send(.appBecameActive)
            }
        }
    }
}
