import SwiftUI
import ComposableArchitecture

struct CalendarView: View {
    let store: StoreOf<CalendarFeature>

    var body: some View {
        List {
            if !store.suggestedGaps.isEmpty {
                Section("Suggested Focus Blocks") {
                    ForEach(store.suggestedGaps) { gap in
                        Button { store.send(.suggestedBlockTapped(gap)) } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading) {
                                    Text("Focus block")
                                        .font(.subheadline.bold())
                                    Text("\(gap.start, style: .time) – \(gap.end, style: .time)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(gap.duration / 60))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Today's Events") {
                if store.events.isEmpty {
                    Text("No events today")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.events) { event in
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.blue)
                                .frame(width: 4)
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.subheadline)
                                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}
