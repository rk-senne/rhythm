import Foundation
import ComposableArchitecture

@DependencyClient
struct TimerClient {
    var start: @Sendable (Int) async -> AsyncStream<Int> = { _ in .finished }
}

extension TimerClient: DependencyKey {
    static let liveValue = TimerClient(
        start: { duration in
            AsyncStream { continuation in
                Task {
                    for remaining in stride(from: duration, through: 0, by: -1) {
                        continuation.yield(remaining)
                        try? await Task.sleep(for: .seconds(1))
                    }
                    continuation.finish()
                }
            }
        }
    )
}

extension DependencyValues {
    var timerClient: TimerClient {
        get { self[TimerClient.self] }
        set { self[TimerClient.self] = newValue }
    }
}
