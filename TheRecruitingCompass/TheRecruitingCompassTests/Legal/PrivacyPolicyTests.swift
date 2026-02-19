import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class PrivacyPolicyTests: XCTestCase {
  // MARK: - PrivacyPolicy Model Tests

  func testBundledPolicyExists() {
    let policy = PrivacyPolicy.bundled

    XCTAssertEqual(policy.lastUpdated, Date(timeIntervalSince1970: 1739404800))
  }

  func testFormattedDateReturnsNonEmptyString() {
    let policy = PrivacyPolicy.bundled

    let formatted = policy.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026"))
  }

  func testFormattedDateUsesLongStyle() {
    let date = Date(timeIntervalSince1970: 1739404800) // February 19, 2026
    let policy = PrivacyPolicy(lastUpdated: date)

    let formatted = policy.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026"))
  }

  func testBundledContentLastUpdatedTimestamp() {
    let expected = Date(timeIntervalSince1970: 1739404800)
    XCTAssertEqual(PrivacyPolicy.bundled.lastUpdated, expected)
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
