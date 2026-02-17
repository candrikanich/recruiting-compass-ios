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
  // Note: SwiftUI Color equality is unreliable in XCTest — compare via UIColor RGBA components.

  func testStatusColor_Accepted() {
    assertColorMatches(OfferStatus.accepted.statusColor, expected: .successGreen)
  }

  func testStatusColor_Pending() {
    assertColorMatches(OfferStatus.pending.statusColor, expected: .accentBlue)
  }

  func testStatusColor_Declined() {
    assertColorMatches(OfferStatus.declined.statusColor, expected: .errorRed)
  }

  func testStatusColor_Expired() {
    assertColorMatches(OfferStatus.expired.statusColor, expected: .iconGray)
  }

  func testStatusColor_AllDistinct() {
    let colors = OfferStatus.allCases.map { UIColor($0.statusColor) }
    let unique = Set(colors.map { colorKey($0) })
    XCTAssertEqual(unique.count, 4, "Each status should have a unique color")
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

  // MARK: - Helpers

  private func assertColorMatches(_ color: Color, expected: Color, tolerance: CGFloat = 0.01, file: StaticString = #file, line: UInt = #line) {
    let c1 = UIColor(color).cgColor.components ?? []
    let c2 = UIColor(expected).cgColor.components ?? []
    guard c1.count >= 3, c2.count >= 3 else {
      XCTFail("Could not extract RGB components", file: file, line: line)
      return
    }
    XCTAssertEqual(c1[0], c2[0], accuracy: tolerance, "Red mismatch", file: file, line: line)
    XCTAssertEqual(c1[1], c2[1], accuracy: tolerance, "Green mismatch", file: file, line: line)
    XCTAssertEqual(c1[2], c2[2], accuracy: tolerance, "Blue mismatch", file: file, line: line)
  }

  private func colorKey(_ color: UIColor) -> String {
    let c = color.cgColor.components ?? []
    guard c.count >= 3 else { return "unknown" }
    return String(format: "%.2f-%.2f-%.2f", c[0], c[1], c[2])
  }
}
