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
            case .notifications:
                notificationsStep
            case .healthKit:
                healthKitStep
            case .duration:
                durationStep
            case .done:
                EmptyView()
            }

            Spacer()

            Button("Continue") { store.send(.nextTapped) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Welcome to Rhythm")
                .font(.largeTitle.bold())
            Text("Structure your day into focused cycles aligned with your body's natural rhythm.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("Stay on Rhythm")
                .font(.title.bold())
            Text("Get gentle nudges when it's time for your next cycle or ritual.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Enable Notifications") { store.send(.requestNotifications) }
                .buttonStyle(.bordered)
        }
    }

    private var healthKitStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("Track Hydration")
                .font(.title.bold())
            Text("Log water intake to Apple Health alongside your focus sessions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Connect Health") { store.send(.requestHealthKit) }
                .buttonStyle(.bordered)
        }
    }

    private var durationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("Focus Duration")
                .font(.title.bold())
            Text("How long do you want to focus per session?")
                .foregroundStyle(.secondary)
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
}
