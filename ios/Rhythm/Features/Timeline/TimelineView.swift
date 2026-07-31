import SwiftUI
import ComposableArchitecture

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StreakHeaderView(streak: store.streak, message: store.streakMessage)
                }

                Section("Today") {
                    if store.cycles.isEmpty {
                        ContentUnavailableView("No cycles yet", systemImage: "clock", description: Text("Start your first focus session"))
                    } else {
                        ForEach(store.cycles) { cycle in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cycle.startedAt, style: .time)
                                        .font(.headline)
                                    Text("\(cycle.duration / 60) min focus")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if cycle.ritualCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .onAppear { store.send(.onAppear) }
        }
    }
}

/// Calm, non-punitive streak header (see docs/RESEARCH_FINDINGS_2026.md rec #2).
struct StreakHeaderView: View {
    let streak: GentleStreak
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(streak.isActiveToday ? .green : .secondary)
                Text(streak.current == 1 ? "1 day of rhythm" : "\(streak.current) days of rhythm")
                    .font(.headline)
                Spacer()
                if streak.longest > streak.current {
                    Text("best \(streak.longest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
