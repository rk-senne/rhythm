import WidgetKit
import SwiftUI

struct CycleStatusEntry: TimelineEntry {
    let date: Date
    let cyclesCompleted: Int
    let isInFocus: Bool
}

struct CycleStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> CycleStatusEntry {
        CycleStatusEntry(date: .now, cyclesCompleted: 2, isInFocus: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleStatusEntry) -> Void) {
        completion(CycleStatusEntry(date: .now, cyclesCompleted: 2, isInFocus: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleStatusEntry>) -> Void) {
        let entry = CycleStatusEntry(date: .now, cyclesCompleted: 0, isInFocus: false)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct CycleStatusComplication: Widget {
    let kind = "CycleStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CycleStatusProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    if entry.isInFocus {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                    } else {
                        Text("\(entry.cyclesCompleted)")
                            .font(.system(.title3, design: .rounded).bold())
                        Text("cycles")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .configurationDisplayName("Rhythm")
        .description("Cycle status on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}
