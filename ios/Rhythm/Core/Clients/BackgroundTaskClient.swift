import BackgroundTasks
import Foundation
import ComposableArchitecture

@DependencyClient
struct BackgroundTaskClient {
    var scheduleTimerEnd: @Sendable (Date) async -> Void = { _ in }
    var cancelPending: @Sendable () async -> Void = {}
}

extension BackgroundTaskClient: DependencyKey {
    static let liveValue = BackgroundTaskClient(
        scheduleTimerEnd: { endDate in
            let request = BGAppRefreshTaskRequest(identifier: "com.rhythm.timer.end")
            request.earliestBeginDate = endDate
            try? BGTaskScheduler.shared.submit(request)
        },
        cancelPending: {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
    )
}

extension DependencyValues {
    var backgroundTaskClient: BackgroundTaskClient {
        get { self[BackgroundTaskClient.self] }
        set { self[BackgroundTaskClient.self] = newValue }
    }
}
