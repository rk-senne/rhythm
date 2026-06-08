import SwiftUI
import ComposableArchitecture

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>

    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Timeline")
            .onAppear { store.send(.onAppear) }
        }
    }
}
