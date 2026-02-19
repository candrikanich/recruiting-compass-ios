import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class TermsOfServiceTests: XCTestCase {
  // MARK: - TermsOfService Model Tests

  func testBundledTermsExists() {
    let terms = TermsOfService.bundled

    XCTAssertEqual(terms.lastUpdated, Date(timeIntervalSince1970: 1739404800))
  }

  func testFormattedDateReturnsNonEmptyString() {
    let terms = TermsOfService.bundled

    let formatted = terms.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026"))
  }

  func testFormattedDateUsesLongStyle() {
    let date = Date(timeIntervalSince1970: 1739404800) // February 19, 2026
    let terms = TermsOfService(lastUpdated: date)

    let formatted = terms.formattedDate

    XCTAssertFalse(formatted.isEmpty)
    XCTAssertTrue(formatted.contains("2026"))
  }

  func testBundledContentLastUpdatedTimestamp() {
    let expected = Date(timeIntervalSince1970: 1739404800)
    XCTAssertEqual(TermsOfService.bundled.lastUpdated, expected)
  }

  func testBundledContentFormattedDate() {
    let terms = TermsOfService.bundled
    let formatted = terms.formattedDate
    XCTAssertFalse(formatted.isEmpty)
  }

  // MARK: - TermsOfServiceView Tests

  @MainActor
  func testTermsOfServiceViewCanBeConstructed() {
    let view = TermsOfServiceView()
    XCTAssertNotNil(view)
  }
}
