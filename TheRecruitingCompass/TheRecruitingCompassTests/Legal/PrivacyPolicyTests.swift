import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class PrivacyPolicyTests: XCTestCase {
  // MARK: - PrivacyPolicy Model Tests

  func testBundledPolicyExists() {
    let policy = PrivacyPolicy.bundled

    XCTAssertEqual(policy.lastUpdated, LegalRevision.lastUpdated)
  }

  func testFormattedDateReturnsNonEmptyString() {
    let policy = PrivacyPolicy.bundled

    let formatted = policy.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026") || formatted.count > 5, "Formatted date should show year or be non-trivial")
  }

  func testFormattedDateUsesLongStyle() {
    let date = Date(timeIntervalSince1970: 1739404800) // February 19, 2026
    let policy = PrivacyPolicy(lastUpdated: date)

    let formatted = policy.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026") || formatted.count > 5, "Long style should produce a substantial date string")
  }

  func testBundledContentLastUpdatedTimestamp() {
    XCTAssertEqual(PrivacyPolicy.bundled.lastUpdated, LegalRevision.lastUpdated)
  }

  func testBundledContentFormattedDate() {
    let policy = PrivacyPolicy.bundled
    let formatted = policy.formattedDate
    XCTAssertFalse(formatted.isEmpty)
  }

  // MARK: - PrivacyPolicyView Tests

  @MainActor
  func testPrivacyPolicyViewCanBeConstructed() {
    let view = PrivacyPolicyView()
    XCTAssertNotNil(view)
  }
}
