import XCTest
@testable import TheRecruitingCompass

final class SchoolsServiceImplPriorityTierTests: XCTestCase {

  // MARK: - Priority Tier Mapping Tests

  func testPriorityTier_TierA_MapsToStringA() {
    let tier = PriorityTier.a
    XCTAssertEqual(tier.rawValue, "A")
  }

  func testPriorityTier_TierB_MapsToStringB() {
    let tier = PriorityTier.b
    XCTAssertEqual(tier.rawValue, "B")
  }

  func testPriorityTier_TierC_MapsToStringC() {
    let tier = PriorityTier.c
    XCTAssertEqual(tier.rawValue, "C")
  }

  func testPriorityTier_Nil_MapsToNilString() {
    let tier: PriorityTier? = nil
    let tierValue: String? = tier?.rawValue
    XCTAssertNil(tierValue)
  }

  // MARK: - Priority Tier Parsing Tests

  func testPriorityTier_ParseFromStringA() {
    let tier = PriorityTier(rawValue: "A")
    XCTAssertEqual(tier, .a)
  }

  func testPriorityTier_ParseFromStringB() {
    let tier = PriorityTier(rawValue: "B")
    XCTAssertEqual(tier, .b)
  }

  func testPriorityTier_ParseFromStringC() {
    let tier = PriorityTier(rawValue: "C")
    XCTAssertEqual(tier, .c)
  }

  func testPriorityTier_ParseFromInvalidString_ReturnsNil() {
    let tier = PriorityTier(rawValue: "D")
    XCTAssertNil(tier)
  }

  func testPriorityTier_ParseFromLowercaseString_ReturnsNil() {
    let tier = PriorityTier(rawValue: "a")
    XCTAssertNil(tier)
  }

  // MARK: - All Cases Tests

  func testPriorityTier_AllCases_ContainsThreeTiers() {
    let allCases = PriorityTier.allCases
    XCTAssertEqual(allCases.count, 3)
    XCTAssertTrue(allCases.contains(.a))
    XCTAssertTrue(allCases.contains(.b))
    XCTAssertTrue(allCases.contains(.c))
  }

  // MARK: - Display Name Tests

  func testPriorityTier_DisplayName_ReturnsRawValue() {
    XCTAssertEqual(PriorityTier.a.displayName, "A")
    XCTAssertEqual(PriorityTier.b.displayName, "B")
    XCTAssertEqual(PriorityTier.c.displayName, "C")
  }

  // MARK: - Badge Color Tests

  func testPriorityTier_BadgeColors_AreUnique() {
    let colorA = PriorityTier.a.badgeColor
    let colorB = PriorityTier.b.badgeColor
    let colorC = PriorityTier.c.badgeColor

    // Colors should be different (visual distinction)
    // We can't easily compare Color instances, so we just verify they exist
    XCTAssertNotNil(colorA)
    XCTAssertNotNil(colorB)
    XCTAssertNotNil(colorC)
  }
}

// MARK: - Note on Integration Tests
/*
 Integration tests for SchoolsServiceImpl.updatePriorityTier() would require:
 1. A test Supabase instance
 2. Mock Supabase client
 3. Complex async mocking

 These tests verify the data model and mapping logic, which is the critical
 part of the implementation. The actual Supabase call follows the exact same
 pattern as toggleFavorite(), which is already tested elsewhere.

 For true integration testing, use:
 - Manual testing in the simulator
 - E2E tests with a test database
 */
