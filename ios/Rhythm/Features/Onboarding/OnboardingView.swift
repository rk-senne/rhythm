import SwiftUI
import ComposableArchitecture

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            switch store.step {
            case .welcome:
                welcomeStep
            case .miniCycle:
                miniCycleStep
            case .duration:
                durationStep
            case .notifications:
                notificationsStep
            case .healthKit:
                healthKitStep
            case .done:
                EmptyView()
            }

            Spacer()

            Button(continueTitle) { store.send(.nextTapped) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .animation(.easeInOut, value: store.step)
    }

    private var continueTitle: String {
        switch store.step {
        case .welcome: return "Begin"
        case .miniCycle: return "That's the rhythm"
        case .duration: return "Continue"
        case .notifications: return store.notificationsGranted ? "Continue" : "Not now"
        case .healthKit: return "Start using Rhythm"
        case .done: return "Continue"
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Welcome to Rhythm")
                .font(.largeTitle.bold())
            Text("Work in focused cycles aligned with your body's natural rhythm — then reset with a short ritual. Let's try the reset right now.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    // First-value moment: a real breathing reset, before any permission ask.
    private var miniCycleStep: some View {
        VStack(spacing: 20) {
            Text("Your first reset")
                .font(.title.bold())
            Text("Follow the circle. Four slow breaths — this is how every cycle ends.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            BreatheView()
                .frame(maxHeight: 320)
        }
    }

    private var durationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("How long do you focus?")
                .font(.title.bold())
            Text("Pick a cycle length. You can change this any time.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("Duration", selection: Binding(
                get: { store.selectedDuration },
                set: { store.send(.durationSelected($0)) }
            )) {
                Text("45 min").tag(45)
                Text("60 min").tag(60)
                Text("90 min").tag(90)
            }
            .pickerStyle(.segmented)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("One gentle nudge")
                .font(.title.bold())
            Text("We'll send a single reminder when it's time to reset — never more. You can skip this.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(store.notificationsGranted ? "Enabled ✓" : "Enable Notifications") {
                store.send(.requestNotifications)
            }
            .buttonStyle(.bordered)
            .disabled(store.notificationsGranted)
        }
    }

    private var healthKitStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("Track hydration (optional)")
                .font(.title.bold())
            Text("Log water to Apple Health during your rituals. Totally optional.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(store.healthKitGranted ? "Connected ✓" : "Connect Health") {
                store.send(.requestHealthKit)
            }
            .buttonStyle(.bordered)
            .disabled(store.healthKitGranted)
        }
    }
}
