import ActivityKit
import WidgetKit
import SwiftUI

struct FocusSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var isPaused: Bool
    }

    var focusDurationMinutes: Int
}

struct FocusSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            // Lock screen banner
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Focus Session")
                        .font(.headline)
                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                        .font(.system(.title2, design: .monospaced))
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(.indigo.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text("Focus")
                            .font(.headline)
                        Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                            .font(.system(.title, design: .monospaced))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                }
            } compactLeading: {
                Image(systemName: "brain.head.profile")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 56)
            } minimal: {
                Image(systemName: "brain.head.profile")
            }
        }
    }
}
