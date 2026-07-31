import SwiftUI
import ComposableArchitecture

struct TimerView: View {
    let store: StoreOf<TimerFeature>
    /// Starting a cycle is routed through the app so the free-tier gate can
    /// intercept (ending is not gated).
    var onStart: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text(formatted(store.secondsRemaining))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text(timeAccessibilityLabel(store.secondsRemaining)))

                Button(store.isRunning ? "End Session" : "Start Focus") {
                    if store.isRunning {
                        store.send(.stopTapped)
                    } else {
                        onStart()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .navigationTitle("Focus")
        }
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func timeAccessibilityLabel(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m > 0 && s > 0 { return "\(m) minutes \(s) seconds remaining" }
        if m > 0 { return "\(m) minutes remaining" }
        return "\(s) seconds remaining"
    }
}
