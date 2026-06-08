import SwiftUI
import ComposableArchitecture

struct TimerView: View {
    let store: StoreOf<TimerFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text(formatted(store.secondsRemaining))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .contentTransition(.numericText())

                Button(store.isRunning ? "End Session" : "Start Focus") {
                    store.send(store.isRunning ? .stopTapped : .startTapped)
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
}
