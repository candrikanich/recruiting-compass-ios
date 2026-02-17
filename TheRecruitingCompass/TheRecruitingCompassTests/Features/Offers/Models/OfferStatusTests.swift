import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class OfferStatusTests: XCTestCase {

  // MARK: - displayName Tests

  func testDisplayName_Pending() {
    XCTAssertEqual(OfferStatus.pending.displayName, "Pending")
  }

  func testDisplayName_Accepted() {
    XCTAssertEqual(OfferStatus.accepted.displayName, "Accepted")
  }

  func testDisplayName_Declined() {
    XCTAssertEqual(OfferStatus.declined.displayName, "Declined")
  }

  func testDisplayName_Expired() {
    XCTAssertEqual(OfferStatus.expired.displayName, "Expired")
  }

  // MARK: - statusColor Tests

  func testStatusColor_Accepted() {
    XCTAssertEqual(OfferStatus.accepted.statusColor, .successGreen)
  }

  func testStatusColor_Pending() {
    XCTAssertEqual(OfferStatus.pending.statusColor, .accentBlue)
  }

  func testStatusColor_Declined() {
    XCTAssertEqual(OfferStatus.declined.statusColor, .errorRed)
  }

  func testStatusColor_Expired() {
    XCTAssertEqual(OfferStatus.expired.statusColor, .iconGray)
  }

  // MARK: - CaseIterable Tests

  func testAllCases_ContainsFourStatuses() {
    XCTAssertEqual(OfferStatus.allCases.count, 4)
  }

  func testAllCases_ContainsExpectedStatuses() {
    let allCases = OfferStatus.allCases
    XCTAssertTrue(allCases.contains(.pending))
    XCTAssertTrue(allCases.contains(.accepted))
    XCTAssertTrue(allCases.contains(.declined))
    XCTAssertTrue(allCases.contains(.expired))
  }

  // MARK: - Codable Tests

  func testCodable_RoundTrip() throws {
    for status in OfferStatus.allCases {
      let data = try JSONEncoder().encode(status)
      let decoded = try JSONDecoder().decode(OfferStatus.self, from: data)
      XCTAssertEqual(decoded, status)
    }
  }

  func testRawValue_Pending() {
    XCTAssertEqual(OfferStatus.pending.rawValue, "pending")
  }

  func testRawValue_Accepted() {
    XCTAssertEqual(OfferStatus.accepted.rawValue, "accepted")
  }

  func testRawValue_Declined() {
    XCTAssertEqual(OfferStatus.declined.rawValue, "declined")
  }

  func testRawValue_Expired() {
    XCTAssertEqual(OfferStatus.expired.rawValue, "expired")
  }
}
