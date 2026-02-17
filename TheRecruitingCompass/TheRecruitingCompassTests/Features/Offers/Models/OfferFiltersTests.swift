import XCTest
@testable import TheRecruitingCompass

final class OfferFiltersTests: XCTestCase {

  // MARK: - Default Initialization

  func testDefaultInitialization() {
    let filters = OfferFilters()

    XCTAssertTrue(filters.schoolSearch.isEmpty)
    XCTAssertNil(filters.status)
    XCTAssertNil(filters.offerType)
    XCTAssertEqual(filters.sortBy, .offerDate)
    XCTAssertEqual(filters.sortDirection, .descending)
  }

  // MARK: - hasActiveFilters Tests

  func testHasActiveFilters_Default_ReturnsFalse() {
    let filters = OfferFilters()
    XCTAssertFalse(filters.hasActiveFilters)
  }

  func testHasActiveFilters_WithSchoolSearch_ReturnsTrue() {
    var filters = OfferFilters()
    filters.schoolSearch = "UCLA"
    XCTAssertTrue(filters.hasActiveFilters)
  }

  func testHasActiveFilters_WithStatus_ReturnsTrue() {
    var filters = OfferFilters()
    filters.status = .pending
    XCTAssertTrue(filters.hasActiveFilters)
  }

  func testHasActiveFilters_WithOfferType_ReturnsTrue() {
    var filters = OfferFilters()
    filters.offerType = .fullRide
    XCTAssertTrue(filters.hasActiveFilters)
  }

  func testHasActiveFilters_SortChangesDoNotCount() {
    var filters = OfferFilters()
    filters.sortBy = .amount
    filters.sortDirection = .ascending
    XCTAssertFalse(filters.hasActiveFilters)
  }

  // MARK: - activeFilterCount Tests

  func testActiveFilterCount_Default_ReturnsZero() {
    let filters = OfferFilters()
    XCTAssertEqual(filters.activeFilterCount, 0)
  }

  func testActiveFilterCount_OneFilter() {
    var filters = OfferFilters()
    filters.status = .accepted
    XCTAssertEqual(filters.activeFilterCount, 1)
  }

  func testActiveFilterCount_TwoFilters() {
    var filters = OfferFilters()
    filters.status = .accepted
    filters.offerType = .fullRide
    XCTAssertEqual(filters.activeFilterCount, 2)
  }

  func testActiveFilterCount_AllThreeFilters() {
    var filters = OfferFilters()
    filters.schoolSearch = "Stanford"
    filters.status = .pending
    filters.offerType = .partial
    XCTAssertEqual(filters.activeFilterCount, 3)
  }

  // MARK: - OfferSortField Tests

  func testOfferSortField_DisplayNames() {
    XCTAssertEqual(OfferSortField.offerDate.displayName, "Offer Date")
    XCTAssertEqual(OfferSortField.deadline.displayName, "Deadline")
    XCTAssertEqual(OfferSortField.percentage.displayName, "Percentage")
    XCTAssertEqual(OfferSortField.amount.displayName, "Amount")
  }

  func testOfferSortField_AllCases() {
    XCTAssertEqual(OfferSortField.allCases.count, 4)
  }

  // MARK: - SortDirection Tests

  func testSortDirection_DisplayNames() {
    XCTAssertEqual(SortDirection.ascending.displayName, "Ascending")
    XCTAssertEqual(SortDirection.descending.displayName, "Descending")
  }

  func testSortDirection_AllCases() {
    XCTAssertEqual(SortDirection.allCases.count, 2)
  }
}
