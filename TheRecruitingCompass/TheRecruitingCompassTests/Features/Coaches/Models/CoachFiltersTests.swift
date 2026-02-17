import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CoachFiltersTests: XCTestCase {

  // MARK: - SchoolId Filter Tests

  func testSchoolIdFilter_IsIncludedInHasActiveFilters() {
    var filters = CoachFilters()
    filters.schoolId = "school-123"

    XCTAssertTrue(filters.hasActiveFilters)
  }

  func testSchoolIdFilter_IsIncludedInActiveFilterCount() {
    var filters = CoachFilters()
    filters.schoolId = "school-123"

    XCTAssertEqual(filters.activeFilterCount, 1)
  }

  func testSchoolIdFilter_WithOtherFilters_IncrementsCount() {
    var filters = CoachFilters()
    filters.schoolId = "school-123"
    filters.role = .head
    filters.lastContactDays = 30

    XCTAssertEqual(filters.activeFilterCount, 3)
  }

  func testNoSchoolIdFilter_DoesNotCountAsActive() {
    var filters = CoachFilters()
    filters.schoolId = nil

    XCTAssertFalse(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 0)
  }

  func testSchoolIdFilter_WithAllFilters_CountsCorrectly() {
    var filters = CoachFilters()
    filters.schoolId = "school-123"
    filters.role = .assistant
    filters.lastContactDays = 7
    filters.responsivenessLevel = .high

    XCTAssertTrue(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 4)
  }

  // MARK: - Equatable Tests

  func testEquality_SameSchoolId() {
    var filters1 = CoachFilters()
    filters1.schoolId = "school-123"

    var filters2 = CoachFilters()
    filters2.schoolId = "school-123"

    XCTAssertEqual(filters1, filters2)
  }

  func testInequality_DifferentSchoolId() {
    var filters1 = CoachFilters()
    filters1.schoolId = "school-123"

    var filters2 = CoachFilters()
    filters2.schoolId = "school-456"

    XCTAssertNotEqual(filters1, filters2)
  }

  func testEquality_BothNilSchoolId() {
    var filters1 = CoachFilters()
    filters1.schoolId = nil

    var filters2 = CoachFilters()
    filters2.schoolId = nil

    XCTAssertEqual(filters1, filters2)
  }

  func testInequality_OneNilSchoolId() {
    var filters1 = CoachFilters()
    filters1.schoolId = "school-123"

    var filters2 = CoachFilters()
    filters2.schoolId = nil

    XCTAssertNotEqual(filters1, filters2)
  }

  // MARK: - Default State Tests

  func testDefaultFilters_NoSchoolId() {
    let filters = CoachFilters()

    XCTAssertNil(filters.schoolId)
  }

  func testDefaultFilters_NoActiveFilters() {
    let filters = CoachFilters()

    XCTAssertFalse(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 0)
  }
}
