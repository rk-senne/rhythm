import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section("Focus") {
                    Picker("Duration", selection: $store.focusDurationMinutes) {
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                        Text("90 min").tag(90)
                    }
                    Toggle("Enable Focus Mode", isOn: $store.enableFocusMode)
                    Toggle("Sound Alerts", isOn: $store.enableSoundAlerts)
                }
                Section("Hydration") {
                    Stepper("Goal: \(store.dailyHydrationGoalMl) ml", value: $store.dailyHydrationGoalMl, in: 500...5000, step: 250)
                }
                Section("Account") {
                    if store.isSignedIn {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            store.send(.signInTapped)
                        } label: {
                            Label("Sign in with Apple", systemImage: "apple.logo")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { store.send(.onAppear) }
        }
    }
}
