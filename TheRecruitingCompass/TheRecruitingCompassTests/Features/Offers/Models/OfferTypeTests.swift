import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OfferTypeTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - displayName Tests

  func testDisplayName_FullRide() {
    XCTAssertEqual(OfferType.fullRide.displayName, "Full Ride")
  }

  func testDisplayName_Partial() {
    XCTAssertEqual(OfferType.partial.displayName, "Partial")
  }

  func testDisplayName_Scholarship() {
    XCTAssertEqual(OfferType.scholarship.displayName, "Scholarship")
  }

  func testDisplayName_RecruitedWalkOn() {
    XCTAssertEqual(OfferType.recruitedWalkOn.displayName, "Recruited Walk-On")
  }

  func testDisplayName_PreferredWalkOn() {
    XCTAssertEqual(OfferType.preferredWalkOn.displayName, "Preferred Walk-On")
  }

  // MARK: - rawValue Tests

  func testRawValue_FullRide() {
    XCTAssertEqual(OfferType.fullRide.rawValue, "full_ride")
  }

  func testRawValue_Partial() {
    XCTAssertEqual(OfferType.partial.rawValue, "partial")
  }

  func testRawValue_Scholarship() {
    XCTAssertEqual(OfferType.scholarship.rawValue, "scholarship")
  }

  func testRawValue_RecruitedWalkOn() {
    XCTAssertEqual(OfferType.recruitedWalkOn.rawValue, "recruited_walk_on")
  }

  func testRawValue_PreferredWalkOn() {
    XCTAssertEqual(OfferType.preferredWalkOn.rawValue, "preferred_walk_on")
  }

  // MARK: - CaseIterable Tests

  func testAllCases_ContainsFiveTypes() {
    XCTAssertEqual(OfferType.allCases.count, 6) // 5 known + .unknown
  }

  func testAllCases_ContainsExpectedTypes() {
    let allCases = OfferType.allCases
    XCTAssertTrue(allCases.contains(.fullRide))
    XCTAssertTrue(allCases.contains(.partial))
    XCTAssertTrue(allCases.contains(.scholarship))
    XCTAssertTrue(allCases.contains(.recruitedWalkOn))
    XCTAssertTrue(allCases.contains(.preferredWalkOn))
  }

  // MARK: - Codable Tests

  func testCodable_RoundTrip() throws {
    for offerType in OfferType.allCases {
      let data = try JSONEncoder().encode(offerType)
      let decoded = try JSONDecoder().decode(OfferType.self, from: data)
      XCTAssertEqual(decoded, offerType)
    }
  }

  func testInitFromRawValue_Valid() {
    XCTAssertEqual(OfferType(rawValue: "full_ride"), .fullRide)
    XCTAssertEqual(OfferType(rawValue: "partial"), .partial)
    XCTAssertEqual(OfferType(rawValue: "scholarship"), .scholarship)
    XCTAssertEqual(OfferType(rawValue: "recruited_walk_on"), .recruitedWalkOn)
    XCTAssertEqual(OfferType(rawValue: "preferred_walk_on"), .preferredWalkOn)
  }

  func testInitFromRawValue_Invalid() {
    XCTAssertNil(OfferType(rawValue: "invalid"))
    XCTAssertNil(OfferType(rawValue: ""))
  }
}
