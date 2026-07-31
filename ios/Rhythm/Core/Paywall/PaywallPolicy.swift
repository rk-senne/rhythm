import Foundation

// Free-tier limits and paywall-trigger policy, kept as pure functions so the
// monetization rules are trivially testable and live in one place.
//
// Grounded in docs/RESEARCH_FINDINGS_2026.md:
//   • rec #4 — a *generous* free tier (3 cycles/day) so the habit forms before
//     the wall; and
//   • rec #7 — trigger the paywall when the user *hits value* (their free daily
//     limit), never on day 0.

enum FreeTier {
    /// Focus cycles a free user can start per day. Pro is unlimited.
    static let dailyCycleLimit = 3
}

enum PaywallPolicy {
    /// Whether the user may start another focus cycle right now.
    static func canStartCycle(cyclesCompletedToday: Int, isPro: Bool) -> Bool {
        isPro || cyclesCompletedToday < FreeTier.dailyCycleLimit
    }

    /// Whether to surface the paywall. Fires once, for a non-Pro user, at the
    /// moment they reach the free daily limit (they've felt the value). Callers
    /// track `hasSeenPaywall` so it isn't shown repeatedly.
    static func shouldTriggerPaywall(cyclesCompletedToday: Int, isPro: Bool, hasSeenPaywall: Bool) -> Bool {
        !isPro && !hasSeenPaywall && cyclesCompletedToday >= FreeTier.dailyCycleLimit
    }
}
