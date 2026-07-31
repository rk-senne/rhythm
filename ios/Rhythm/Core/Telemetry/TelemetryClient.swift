import ComposableArchitecture
import Foundation

// A thin analytics/telemetry seam. Call sites emit well-known events; the live
// implementation is swappable (TelemetryDeck, PostHog, Sentry breadcrumbs, …)
// without touching any feature code. See docs/DEPLOYMENT.md to wire a real SDK.
//
// Privacy: event properties must never contain PII (no journal text, no emails).

struct TelemetryEvent: Equatable {
    let name: String
    let properties: [String: String]

    init(_ name: String, _ properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

struct TelemetryClient: Sendable {
    var track: @Sendable (TelemetryEvent) -> Void = { _ in }
}

extension TelemetryClient: DependencyKey {
    /// Default: log in DEBUG, no-op in release. Replace with a real analytics
    /// SDK's send call — no call sites change.
    static let liveValue = TelemetryClient(
        track: { event in
            #if DEBUG
            print("📊 telemetry:", event.name, event.properties)
            #endif
        }
    )

    /// Tests get a silent no-op unless they override `track` to assert events.
    static let testValue = TelemetryClient(track: { _ in })
}

extension DependencyValues {
    var telemetry: TelemetryClient {
        get { self[TelemetryClient.self] }
        set { self[TelemetryClient.self] = newValue }
    }
}

// Well-known events (avoid stringly-typed sprinkles at call sites).
extension TelemetryEvent {
    static let cycleCompleted = TelemetryEvent("cycle_completed")
    static let onboardingCompleted = TelemetryEvent("onboarding_completed")
    static func paywallShown(reason: String) -> TelemetryEvent {
        TelemetryEvent("paywall_shown", ["reason": reason])
    }
}
