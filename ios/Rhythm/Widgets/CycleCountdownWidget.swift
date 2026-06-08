import WidgetKit
import SwiftUI

// MARK: - Shared Entry

struct RhythmEntry: TimelineEntry {
    let date: Date
    let cyclesCompleted: Int
    let cyclesGoal: Int
    let upcomingEvents: [WidgetEvent]
}

struct WidgetEvent {
    let title: String
    let start: Date
    let isFocusBlock: Bool
}

struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: .now, cyclesCompleted: 2, cyclesGoal: 4, upcomingEvents: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        completion(RhythmEntry(date: .now, cyclesCompleted: 2, cyclesGoal: 4, upcomingEvents: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        // TODO: read from App Group shared container
        let entry = RhythmEntry(date: .now, cyclesCompleted: 0, cyclesGoal: 4, upcomingEvents: [])
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

// MARK: - Small: Progress Ring

struct ProgressRingWidget: Widget {
    let kind = "ProgressRing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RhythmProvider()) { entry in
            ProgressRingView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Progress")
        .description("Cycles completed today.")
        .supportedFamilies([.systemSmall])
    }
}

struct ProgressRingView: View {
    let entry: RhythmEntry

    private var progress: Double {
        guard entry.cyclesGoal > 0 else { return 0 }
        return Double(entry.cyclesCompleted) / Double(entry.cyclesGoal)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.indigo.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(entry.cyclesCompleted)")
                        .font(.system(.title, design: .rounded).bold())
                    Text("of \(entry.cyclesGoal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text("Cycles")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Medium: Mini Timeline

struct MiniTimelineWidget: Widget {
    let kind = "MiniTimeline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RhythmProvider()) { entry in
            MiniTimelineView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Timeline")
        .description("Your next 3 hours at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct MiniTimelineView: View {
    let entry: RhythmEntry

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring (compact)
            ZStack {
                Circle()
                    .stroke(.indigo.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(entry.cyclesCompleted) / Double(max(entry.cyclesGoal, 1)))
                    .stroke(.indigo, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(entry.cyclesCompleted)/\(entry.cyclesGoal)")
                    .font(.caption2.bold())
            }
            .frame(width: 50, height: 50)

            // Timeline list
            VStack(alignment: .leading, spacing: 6) {
                if entry.upcomingEvents.isEmpty {
                    Text("No upcoming events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Start a focus block!")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                } else {
                    ForEach(entry.upcomingEvents.prefix(3), id: \.title) { event in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.isFocusBlock ? .indigo : .blue)
                                .frame(width: 3, height: 16)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event.title)
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                                Text(event.start, style: .time)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Widget Bundle

@main
struct RhythmWidgets: WidgetBundle {
    var body: some Widget {
        ProgressRingWidget()
        MiniTimelineWidget()
        CycleCountdownWidget()
    }
}

// MARK: - Lock Screen Countdown (existing, kept)

struct CycleCountdownWidget: Widget {
    let kind = "CycleCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RhythmProvider()) { entry in
            VStack {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text("\(entry.cyclesCompleted)")
                    .font(.system(.title3, design: .monospaced))
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus")
        .description("Cycles completed today.")
        .supportedFamilies([.accessoryCircular])
    }
}
