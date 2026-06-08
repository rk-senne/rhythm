import ActivityKit
import Foundation
import ComposableArchitecture

@DependencyClient
struct LiveActivityClient {
    var start: @Sendable (Int) async throws -> Void = { _ in }
    var update: @Sendable (Date) async throws -> Void = { _ in }
    var stop: @Sendable () async throws -> Void = {}
}

extension LiveActivityClient: DependencyKey {
    static let liveValue = LiveActivityClient(
        start: { durationSeconds in
            let attributes = FocusSessionAttributes(focusDurationMinutes: durationSeconds / 60)
            let state = FocusSessionAttributes.ContentState(
                endTime: Date.now.addingTimeInterval(TimeInterval(durationSeconds)),
                isPaused: false
            )
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        },
        update: { newEndTime in
            let state = FocusSessionAttributes.ContentState(endTime: newEndTime, isPaused: false)
            for activity in Activity<FocusSessionAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        },
        stop: {
            let state = FocusSessionAttributes.ContentState(endTime: .now, isPaused: false)
            for activity in Activity<FocusSessionAttributes>.activities {
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    )
}

extension DependencyValues {
    var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}
