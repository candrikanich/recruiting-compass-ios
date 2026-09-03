import XCTest
@testable import TheRecruitingCompass

final class FamilySubscriptionTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_788_264_000) // 2026-09-03T12:00:00Z

  private func sub(
    _ status: SubscriptionStatus,
    trialEndsAt: Date? = nil,
    currentPeriodEnd: Date? = nil
  ) -> FamilySubscription {
    FamilySubscription(
      familyUnitId: "fam-1", status: status, source: "founding",
      trialEndsAt: trialEndsAt, currentPeriodEnd: currentPeriodEnd
    )
  }

  func test_canWrite_matrix() {
    XCTAssertTrue(sub(.founding).canWrite(now: now))
    XCTAssertTrue(sub(.active).canWrite(now: now))
    XCTAssertTrue(sub(.comp).canWrite(now: now))
    XCTAssertFalse(sub(.readOnly).canWrite(now: now))
    XCTAssertFalse(sub(.unknown).canWrite(now: now))
    XCTAssertTrue(sub(.trialing, trialEndsAt: now.addingTimeInterval(86_400)).canWrite(now: now))
    XCTAssertFalse(sub(.trialing, trialEndsAt: now.addingTimeInterval(-86_400)).canWrite(now: now))
    XCTAssertFalse(sub(.trialing, trialEndsAt: nil).canWrite(now: now))
  }

  func test_trialDaysLeft() {
    XCTAssertNil(sub(.founding).trialDaysLeft(now: now))
    XCTAssertEqual(sub(.trialing, trialEndsAt: now.addingTimeInterval(7 * 86_400)).trialDaysLeft(now: now), 7)
    XCTAssertEqual(sub(.trialing, trialEndsAt: now.addingTimeInterval(-86_400)).trialDaysLeft(now: now), 0)
  }

  func test_planLabel() {
    XCTAssertEqual(sub(.founding).planLabel(now: now), "Founding Family — free for life")
    XCTAssertEqual(sub(.comp).planLabel(now: now), "Complimentary access")
    XCTAssertEqual(sub(.readOnly).planLabel(now: now), "Read-only — subscription needed")
    XCTAssertEqual(
      sub(.trialing, trialEndsAt: now.addingTimeInterval(7 * 86_400)).planLabel(now: now),
      "Free trial — 7 days left"
    )
    let renews = Date(timeIntervalSince1970: 1_819_800_000) // 2027-09-03
    XCTAssertTrue(sub(.active, currentPeriodEnd: renews).planLabel(now: now).hasPrefix("Active — renews "))
    XCTAssertEqual(PlanLabel.unavailable, "Plan unavailable")
  }

  func test_decodesSnakeCaseAndUnknownStatus() throws {
    let json = """
    {"family_unit_id":"fam-1","status":"paused","source":"apple",
     "trial_ends_at":null,"current_period_end":"2027-09-03T00:00:00+00:00",
     "provider_customer_id":null,"provider_product_id":null,
     "created_at":"2026-09-03T00:00:00+00:00","updated_at":"2026-09-03T00:00:00+00:00"}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(FamilySubscription.self, from: json)
    XCTAssertEqual(decoded.status, .unknown)
    XCTAssertEqual(decoded.source, "apple")
    XCTAssertNotNil(decoded.currentPeriodEnd)
  }
}
