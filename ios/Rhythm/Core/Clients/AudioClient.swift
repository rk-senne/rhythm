import Foundation
import ComposableArchitecture

@DependencyClient
struct AudioClient {
    var startRecording: @Sendable () async throws -> Void
    var stopRecording: @Sendable () async throws -> URL = { URL(filePath: "") }
    var transcribe: @Sendable (URL) async throws -> String = { _ in "" }
}

extension AudioClient: DependencyKey {
    static let liveValue = AudioClient(
        startRecording: { /* TODO: AVFoundation */ },
        stopRecording: { URL(filePath: "") /* TODO: AVFoundation */ },
        transcribe: { _ in "" /* TODO: Speech framework */ }
    )
}

extension DependencyValues {
    var audioClient: AudioClient {
        get { self[AudioClient.self] }
        set { self[AudioClient.self] = newValue }
    }
}
