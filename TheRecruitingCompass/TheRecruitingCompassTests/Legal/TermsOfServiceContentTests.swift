import XCTest
@testable import TheRecruitingCompass

/// Mirrors web `tests/unit/pages/legal/termsCopy.spec.ts`: subscriptions are billed through Apple only until web
/// billing exists, so the website-billing wording must stay out of the Terms the app renders.
final class TermsOfServiceContentTests: XCTestCase {
  private var subscriptionText: String {
    ([TermsOfServiceContent.subscriptionsHeading] + TermsOfServiceContent.subscriptionClauses).joined(separator: " ")
  }

  func testBillsSubscriptionsThroughAppleOnly() {
    for phrase in ["purchased on our website", "payment processor", "website purchases"] {
      XCTAssertFalse(subscriptionText.localizedCaseInsensitiveContains(phrase), phrase)
    }
  }

  func testKeepsAppleBillingAndCancellationWording() {
    XCTAssertTrue(subscriptionText.contains(
      "Subscriptions are purchased through the Apple App Store and are billed and managed by Apple; cancel through "
        + "your Apple ID subscription settings. Cancellation takes effect at the end of the current billing period."
    ))
  }

  func testKeepsAppleRefundWording() {
    XCTAssertTrue(subscriptionText.contains("Refunds for App Store purchases are governed by Apple's policies."))
  }
}
