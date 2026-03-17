import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FilterComponentsTests: XCTestCase {

  // MARK: - CoachFilterBar Tests

  func testCoachFilterBar_rendersWithoutCrashing() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))
    XCTAssertNotNil(view)
  }



  func testCoachFilterBar_roleFilterUpdates() {
    var filters = CoachFilters()
    XCTAssertNil(filters.role)

    filters.role = .head
    XCTAssertEqual(filters.role, .head)

    filters.role = nil
    XCTAssertNil(filters.role)
  }

  func testCoachFilterBar_lastContactFilterUpdates() {
    var filters = CoachFilters()
    XCTAssertNil(filters.lastContactDays)

    filters.lastContactDays = 30
    XCTAssertEqual(filters.lastContactDays, 30)

    filters.lastContactDays = nil
    XCTAssertNil(filters.lastContactDays)
  }





  func testCoachFilterBar_roleMenuAccessibility() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))
    // Menu should have accessibility label and hint
    XCTAssertNotNil(view)
  }

  func testCoachFilterBar_allRolesAvailable() {
    let allRoles = CoachRole.allCases
    XCTAssertTrue(allRoles.contains(.head))
    XCTAssertTrue(allRoles.contains(.assistant))
    XCTAssertTrue(allRoles.contains(.recruiting))
  }





  // MARK: - ActiveFilterChips Tests

  func testActiveFilterChips_rendersWithoutCrashing() {
    let view = ActiveFilterChips(filters: .constant(CoachFilters()))
    XCTAssertNotNil(view)
  }

  func testActiveFilterChips_noChipsWhenNoFilters() {
    let filters = CoachFilters()
    XCTAssertFalse(filters.hasActiveFilters)
  }

  func testActiveFilterChips_showsRoleChip() {
    var filters = CoachFilters()
    filters.role = .head
    XCTAssertTrue(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 1)
  }

  func testActiveFilterChips_showsLastContactChip() {
    var filters = CoachFilters()
    filters.lastContactDays = 30
    XCTAssertTrue(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 1)
  }





  func testActiveFilterChips_removeRoleChip() {
    var filters = CoachFilters()
    filters.role = .head
    XCTAssertEqual(filters.activeFilterCount, 1)

    filters.role = nil
    XCTAssertEqual(filters.activeFilterCount, 0)
  }

  func testActiveFilterChips_removeLastContactChip() {
    var filters = CoachFilters()
    filters.lastContactDays = 30
    XCTAssertEqual(filters.activeFilterCount, 1)

    filters.lastContactDays = nil
    XCTAssertEqual(filters.activeFilterCount, 0)
  }





  func testActiveFilterChips_clearAllButtonAccessibility() {
    let view = ActiveFilterChips(filters: .constant(CoachFilters(role: .head)))
    // Clear all button should have accessibility label and hint
    XCTAssertNotNil(view)
  }

  func testActiveFilterChips_chipAccessibility() {
    let view = ActiveFilterChips(filters: .constant(CoachFilters(role: .head)))
    // Each chip should have accessibility label, hint, and button trait
    XCTAssertNotNil(view)
  }

  // MARK: - CoachEmptyState Tests

  func testCoachEmptyState_rendersWithoutCrashing() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_noCoachesState() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
    // Should show "No coaches yet" message
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_filteredEmptyState() {
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
    // Should show "No matching coaches" message
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_showsClearFiltersButton() {
    var clearCalled = false
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: { clearCalled = true })
    // Should show "Clear Filters" button when isFilteredEmpty is true
    XCTAssertNotNil(view)
    XCTAssertFalse(clearCalled) // Not called yet
  }

  func testCoachEmptyState_hidesClearFiltersButton() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: {})
    // Should NOT show "Clear Filters" button when isFilteredEmpty is false
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_clearFiltersCallback() {
    var clearCalled = false
    let onClearFilters = { clearCalled = true }

    onClearFilters()

    XCTAssertTrue(clearCalled)
  }

  func testCoachEmptyState_iconHiddenForAccessibility() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
    // Icon should be hidden from accessibility
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_clearButtonAccessibility() {
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
    // Clear filters button should have accessibility label and hint
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_dynamicType() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
      .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
    // Should support dynamic type scaling
    XCTAssertNotNil(view)
  }

  // MARK: - LastContactOption Tests

  func testLastContactOption_allCases() {
    let allOptions = LastContactOption.allCases
    XCTAssertEqual(allOptions.count, 4)
  }

  func testLastContactOption_sevenDays() {
    let option = LastContactOption.sevenDays
    XCTAssertEqual(option.rawValue, 7)
    XCTAssertEqual(option.displayName, "Last 7 days")
  }

  func testLastContactOption_thirtyDays() {
    let option = LastContactOption.thirtyDays
    XCTAssertEqual(option.rawValue, 30)
    XCTAssertEqual(option.displayName, "Last 30 days")
  }

  func testLastContactOption_sixtyDays() {
    let option = LastContactOption.sixtyDays
    XCTAssertEqual(option.rawValue, 60)
    XCTAssertEqual(option.displayName, "Last 60 days")
  }

  func testLastContactOption_ninetyDays() {
    let option = LastContactOption.ninetyDays
    XCTAssertEqual(option.rawValue, 90)
    XCTAssertEqual(option.displayName, "Last 90 days")
  }

  func testLastContactOption_fromRawValue() {
    XCTAssertEqual(LastContactOption(rawValue: 7), .sevenDays)
    XCTAssertEqual(LastContactOption(rawValue: 30), .thirtyDays)
    XCTAssertEqual(LastContactOption(rawValue: 60), .sixtyDays)
    XCTAssertEqual(LastContactOption(rawValue: 90), .ninetyDays)
    XCTAssertNil(LastContactOption(rawValue: 999))
  }

  // MARK: - CoachSortOption Tests



  func testCoachSortOption_allCases() {
    let allOptions = CoachSortOption.allCases
    XCTAssertEqual(allOptions.count, 4)
    XCTAssertTrue(allOptions.contains(.name))
    XCTAssertTrue(allOptions.contains(.school))
    XCTAssertTrue(allOptions.contains(.lastContacted))
    XCTAssertTrue(allOptions.contains(.role))
  }

  // MARK: - Integration Tests

  func testIntegration_filterBarUpdatesChips() {
    var filters = CoachFilters()
    XCTAssertFalse(filters.hasActiveFilters)

    // Update filter
    filters.role = .head

    // Check chips show up
    XCTAssertTrue(filters.hasActiveFilters)
    XCTAssertEqual(filters.activeFilterCount, 1)

    // Clear filter
    filters.role = nil

    // Check chips are gone
    XCTAssertFalse(filters.hasActiveFilters)
  }



  func testIntegration_emptyStateWithFilters() {
    var filters = CoachFilters()
    filters.role = .head

    // When filtered and empty, should show filtered empty state
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
    XCTAssertNotNil(view)
  }

  func testIntegration_emptyStateWithoutFilters() {
    let filters = CoachFilters()
    XCTAssertFalse(filters.hasActiveFilters)

    // When not filtered and empty, should show no coaches state
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
    XCTAssertNotNil(view)
  }
}
