import XCTest
@testable import Rhythm

final class PaywallPolicyTests: XCTestCase {

    func testFreeUserCanStartBelowDailyLimit() {
        XCTAssertTrue(PaywallPolicy.canStartCycle(cyclesCompletedToday: 0, isPro: false))
        XCTAssertTrue(PaywallPolicy.canStartCycle(cyclesCompletedToday: FreeTier.dailyCycleLimit - 1, isPro: false))
    }

    func testFreeUserBlockedAtDailyLimit() {
        XCTAssertFalse(PaywallPolicy.canStartCycle(cyclesCompletedToday: FreeTier.dailyCycleLimit, isPro: false))
        XCTAssertFalse(PaywallPolicy.canStartCycle(cyclesCompletedToday: FreeTier.dailyCycleLimit + 3, isPro: false))
    }

    func testProUserNeverBlocked() {
        XCTAssertTrue(PaywallPolicy.canStartCycle(cyclesCompletedToday: 999, isPro: true))
    }

    func testTriggerFiresOnceAtLimitForFreeUser() {
        XCTAssertTrue(PaywallPolicy.shouldTriggerPaywall(
            cyclesCompletedToday: FreeTier.dailyCycleLimit, isPro: false, hasSeenPaywall: false))
        // Already shown -> don't nag.
        XCTAssertFalse(PaywallPolicy.shouldTriggerPaywall(
            cyclesCompletedToday: FreeTier.dailyCycleLimit, isPro: false, hasSeenPaywall: true))
        // Pro -> never.
        XCTAssertFalse(PaywallPolicy.shouldTriggerPaywall(
            cyclesCompletedToday: FreeTier.dailyCycleLimit, isPro: true, hasSeenPaywall: false))
    }

    func testTriggerDoesNotFireBelowLimit() {
        XCTAssertFalse(PaywallPolicy.shouldTriggerPaywall(
            cyclesCompletedToday: 0, isPro: false, hasSeenPaywall: false))
        XCTAssertFalse(PaywallPolicy.shouldTriggerPaywall(
            cyclesCompletedToday: FreeTier.dailyCycleLimit - 1, isPro: false, hasSeenPaywall: false))
    }
}
