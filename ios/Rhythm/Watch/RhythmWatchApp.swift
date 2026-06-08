import SwiftUI
import WatchKit

@main
struct RhythmWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @State private var selectedTab: WatchTab = .timer

    enum WatchTab { case timer, ritual, hydrate }

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchTimerView()
                .tag(WatchTab.timer)
            WatchRitualView()
                .tag(WatchTab.ritual)
            WatchHydrateView()
                .tag(WatchTab.hydrate)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Timer

struct WatchTimerView: View {
    @State private var isRunning = false
    @State private var secondsRemaining = 5400
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            Text(formatted(secondsRemaining))
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(isRunning ? .indigo : .primary)

            Button(isRunning ? "End" : "Focus") {
                isRunning ? stop() : start()
            }
            .tint(isRunning ? .red : .indigo)
        }
    }

    private func start() {
        isRunning = true
        WKInterfaceDevice.current().play(.start)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
                // Haptic alerts at 10 min, 5 min, 1 min
                if [600, 300, 60].contains(secondsRemaining) {
                    WKInterfaceDevice.current().play(.notification)
                }
            } else {
                stop()
                WKInterfaceDevice.current().play(.success)
            }
        }
    }

    private func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Breathe (haptic-only, no screen needed)

struct WatchRitualView: View {
    @State private var isBreathing = false
    @State private var phase = "Tap to breathe"
    @State private var breathCount = 0

    var body: some View {
        VStack(spacing: 8) {
            Text(phase)
                .font(.headline)
            Text("\(breathCount)/4")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(isBreathing ? "Stop" : "Start") {
                isBreathing ? stopBreathing() : startBreathing()
            }
            .tint(.indigo)
        }
    }

    private func startBreathing() {
        isBreathing = true
        breathCount = 0
        inhale()
    }

    private func stopBreathing() {
        isBreathing = false
        phase = "Tap to breathe"
    }

    private func inhale() {
        guard isBreathing, breathCount < 4 else {
            stopBreathing()
            return
        }
        phase = "In..."
        WKInterfaceDevice.current().play(.directionUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { exhale() }
    }

    private func exhale() {
        guard isBreathing else { return }
        phase = "Out..."
        WKInterfaceDevice.current().play(.directionDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            breathCount += 1
            inhale()
        }
    }
}

// MARK: - Hydrate + Voice Journal

struct WatchHydrateView: View {
    @State private var logged = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                logged = true
                WKInterfaceDevice.current().play(.click)
            } label: {
                VStack {
                    Image(systemName: logged ? "checkmark.circle.fill" : "drop")
                        .font(.title)
                        .foregroundStyle(logged ? .green : .blue)
                    Text(logged ? "Logged" : "Hydrate")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            NavigationLink("Journal") {
                WatchVoiceJournalView()
            }
            .font(.caption)
        }
    }
}

struct WatchVoiceJournalView: View {
    @State private var transcription = ""

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.indigo)
            Text(transcription.isEmpty ? "Tap mic to record" : transcription)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .onTapGesture {
            // WKAudioRecorderController or dictation in watchOS 10+
            presentTextInputController()
        }
    }

    private func presentTextInputController() {
        WKExtension.shared().visibleInterfaceController?.presentTextInputController(
            withSuggestions: ["Great session", "Felt distracted", "Deep flow"],
            allowedInputMode: .allowAnimatedEmoji
        ) { results in
            if let text = results?.first as? String {
                transcription = text
            }
        }
    }
}
