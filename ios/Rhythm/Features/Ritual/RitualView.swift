import SwiftUI
import ComposableArchitecture

struct RitualView: View {
    let store: StoreOf<RitualFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch store.currentStep {
                case .breathe:
                    BreatheView()
                case .hydrate:
                    HydrateView(hydrated: store.hydrated) {
                        store.send(.hydrateToggled)
                    }
                case .journal:
                    JournalView(
                        text: Binding(
                            get: { store.journalText },
                            set: { store.send(.journalTextChanged($0)) }
                        ),
                        selectedMood: store.mood,
                        onMoodSelected: { store.send(.moodSelected($0)) }
                    )
                case .complete:
                    Text("Ritual complete ✓")
                        .font(.title)
                }

                Button("Next") { store.send(.nextStep) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Ritual")
        }
    }
}

struct BreatheView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: BreathePhase = .inhale
    @State private var scale: CGFloat = 0.4
    @State private var breathCount: Int = 0
    private let totalBreaths = 4
    private let breathDuration: Double = 4.0

    enum BreathePhase { case inhale, exhale }

    var body: some View {
        VStack(spacing: 32) {
            Text(phase == .inhale ? "Breathe in" : "Breathe out")
                .font(.title2)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phase)

            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(.indigo.opacity(0.3))
                    .frame(width: 220, height: 220)
                    .scaleEffect(scale)
                Circle()
                    .fill(.indigo.gradient)
                    .frame(width: 100, height: 100)
                    .scaleEffect(scale)
            }
            .accessibilityHidden(true) // decorative; the phase text conveys state

            Text("\(breathCount)/\(totalBreaths)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onAppear { startBreathing() }
    }

    private func startBreathing() {
        breathCount = 0
        inhale()
    }

    // Animate the circle unless the user prefers reduced motion, in which case
    // the breath is still guided by the phase text and haptics.
    private func setScale(_ value: CGFloat) {
        if reduceMotion {
            scale = value
        } else {
            withAnimation(.easeInOut(duration: breathDuration)) { scale = value }
        }
    }

    private func inhale() {
        guard breathCount < totalBreaths else { return }
        phase = .inhale
        HapticEngine.breatheIn()
        setScale(1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + breathDuration) {
            exhale()
        }
    }

    private func exhale() {
        phase = .exhale
        HapticEngine.breatheOut()
        setScale(0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + breathDuration) {
            breathCount += 1
            inhale()
        }
    }
}

enum HapticEngine {
    static func breatheIn() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred(intensity: 0.4)
        // Ramp up subtle taps during inhale
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.0) {
                gen.impactOccurred(intensity: CGFloat(i) * 0.2)
            }
        }
    }

    static func breatheOut() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred(intensity: 0.6)
    }
}

struct HydrateView: View {
    let hydrated: Bool
    let onTap: () -> Void

    var body: some View {
        VStack {
            Text("Hydrate")
                .font(.largeTitle)
            Button(hydrated ? "💧 Logged" : "Tap to log water", action: onTap)
        }
    }
}

struct JournalView: View {
    @Binding var text: String
    let selectedMood: Mood?
    let onMoodSelected: (Mood?) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Reflect")
                .font(.largeTitle)
            TextField("How was your focus?", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            MoodPickerView(selectedMood: selectedMood, onMoodSelected: onMoodSelected)
        }
    }
}

struct MoodPickerView: View {
    let selectedMood: Mood?
    let onMoodSelected: (Mood?) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Mood")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        let newValue: Mood? = selectedMood == mood ? nil : mood
                        onMoodSelected(newValue)
                    } label: {
                        Text(mood.emoji)
                            .font(.title2)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(selectedMood == mood ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.accessibilityLabel)
                    .accessibilityAddTraits(selectedMood == mood ? .isSelected : [])
                }
            }
        }
    }
}

private extension Mood {
    var emoji: String {
        switch self {
        case .great: "😄"
        case .good: "🙂"
        case .neutral: "😐"
        case .low: "😔"
        case .rough: "😣"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .great: "Great"
        case .good: "Good"
        case .neutral: "Neutral"
        case .low: "Low"
        case .rough: "Rough"
        }
    }
}
