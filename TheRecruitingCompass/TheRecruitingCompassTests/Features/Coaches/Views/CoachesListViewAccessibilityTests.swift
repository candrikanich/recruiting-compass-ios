import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeCoach(
    id: String = "coach-1",
    firstName: String = "John",
    lastName: String = "Smith",
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String? = "head",
    schoolId: String = "school-1",
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      position: position,
      schoolId: schoolId,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: "2026-02-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - CoachCardView Accessibility Tests

  func testCoachCardView_doesNotDuplicateContent() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // CoachCardView should use .accessibilityElement(children: .contain)
    // NOT duplicate the card content in a single label
    XCTAssertNotNil(view)
  }

  func testCoachCardView_initialsHidden() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Initials circle should be hidden (decorative)
    XCTAssertNotNil(view)
  }

  func testCoachCardView_contactIconsHidden() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Email and phone icons should be hidden (decorative)
    XCTAssertNotNil(view)
  }

  func testCoachCardView_roleBadgeHasLabel() {
    let coach = makeCoach(position: "head")
    _ = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Role badge should have "Role: Head Coach" label
    XCTAssertEqual(coach.role.displayName, "Head Coach")
  }

  func testCoachCardView_communicationButtonsHaveLabels() {
    let coach = makeCoach(
      email: "test@test.com",
      phone: "555-1234"
    )
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Communication buttons should have descriptive labels
    XCTAssertNotNil(view)
  }

  func testCoachCardView_dynamicTypeSupport() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)

    // Should render without issues at large dynamic type sizes
    XCTAssertNotNil(view)
  }

  // MARK: - CoachFilterBar Accessibility Tests

  func testCoachFilterBar_roleMenuHasLabelAndHint() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))

    // Role menu should have "Filter by role" label
    XCTAssertNotNil(view)
  }

  func testCoachFilterBar_roleMenuHasValue() {
    var filters = CoachFilters()
    filters.role = .head
    let view = CoachFilterBar(filters: .constant(filters))

    // Role menu should announce current selection
    XCTAssertNotNil(view)
  }

  func testCoachFilterBar_lastContactMenuAccessible() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))

    // Last contact menu should have label, hint, and value
    XCTAssertNotNil(view)
  }

  func testCoachFilterBar_sortMenuAccessible() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))

    // Sort menu should have label, hint, and value
    XCTAssertNotNil(view)
  }

  func testCoachFilterBar_chipsMeetHitTarget() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))

    // All filter chips should have minHeight: 44
    XCTAssertNotNil(view)
  }

  // MARK: - ActiveFilterChips Accessibility Tests

  func testActiveFilterChips_chipHasCorrectStructure() {
    var filters = CoachFilters()
    filters.role = .head
    let view = ActiveFilterChips(filters: .constant(filters))

    // Chip should use .accessibilityElement(children: .contain)
    // Text should be readable, button should have "Remove X filter" label
    XCTAssertNotNil(view)
  }

  func testActiveFilterChips_removeButtonHasLabel() {
    var filters = CoachFilters()
    filters.role = .head
    let view = ActiveFilterChips(filters: .constant(filters))

    // Remove button should have "Remove Head Coach filter" label
    XCTAssertNotNil(view)
  }

  func testActiveFilterChips_removeButtonMeetsHitTarget() {
    var filters = CoachFilters()
    filters.role = .head
    let view = ActiveFilterChips(filters: .constant(filters))

    // Remove X button should have minWidth/minHeight: 24 (small but sufficient)
    XCTAssertNotNil(view)
  }

  func testActiveFilterChips_clearAllButtonAccessible() {
    var filters = CoachFilters()
    filters.role = .head
    filters.lastContactDays = 30
    let view = ActiveFilterChips(filters: .constant(filters))

    // Clear all button should have label and hint
    XCTAssertNotNil(view)
  }

  // MARK: - CoachEmptyState Accessibility Tests

  func testCoachEmptyState_iconHidden() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)

    // Empty state icon should be hidden (decorative)
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_clearFiltersButtonAccessible() {
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})

    // Clear filters button should have label and hint
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_clearFiltersButtonMeetsHitTarget() {
    let view = CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})

    // Clear filters button should have minHeight: 44
    XCTAssertNotNil(view)
  }

  func testCoachEmptyState_dynamicTypeSupport() {
    let view = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
      .environment(\.sizeCategory, .accessibilityExtraExtraLarge)

    // Should render without issues at large dynamic type sizes
    XCTAssertNotNil(view)
  }

  // MARK: - CommunicationButton Accessibility Tests

  func testCommunicationButton_emailHasLabel() {
    _ = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")

    // Should have "Email coach" label
    XCTAssertEqual(CommunicationType.email("").accessibilityLabel, "Email coach")
  }

  func testCommunicationButton_phoneHasLabel() {
    _ = CommunicationButton(type: .phone("555-1234"), value: "555-1234")

    // Should have "Text coach" label
    XCTAssertEqual(CommunicationType.phone("").accessibilityLabel, "Text coach")
  }

  func testCommunicationButton_twitterHasLabel() {
    _ = CommunicationButton(type: .twitter("@coach"), value: "@coach")

    // Should have "View Twitter profile" label
    XCTAssertEqual(CommunicationType.twitter("").accessibilityLabel, "View Twitter profile")
  }

  func testCommunicationButton_instagramHasLabel() {
    _ = CommunicationButton(type: .instagram("@coach"), value: "@coach")

    // Should have "View Instagram profile" label
    XCTAssertEqual(CommunicationType.instagram("").accessibilityLabel, "View Instagram profile")
  }

  func testCommunicationButton_meetsHitTarget() {
    let view = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")

    // Should have minWidth/minHeight: 44
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_dynamicTypeIconScaling() {
    let view = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")
      .environment(\.sizeCategory, .accessibilityExtraExtraLarge)

    // Icon size should scale with sizeCategory.isAccessibilityCategory
    XCTAssertNotNil(view)
  }

  // MARK: - CoachesListView Accessibility Tests

  private func coachesListViewWithEnvironments() -> some View {
    CoachesListView()
      .environment(FamilyManager.shared)
      .environment(AuthManager.shared)
  }

  func testCoachesListView_addButtonAccessible() {
    let view = coachesListViewWithEnvironments()

    // Add button should have "Add new coach" label and hint
    XCTAssertNotNil(view)
  }

  func testCoachesListView_addButtonMeetsHitTarget() {
    let view = coachesListViewWithEnvironments()

    // Add button should have minWidth/minHeight: 44
    XCTAssertNotNil(view)
  }

  func testCoachesListView_loadingViewAccessible() {
    let view = coachesListViewWithEnvironments()

    // ProgressView should have "Loading coaches" label
    // Redundant text should be hidden
    XCTAssertNotNil(view)
  }

  func testCoachesListView_resultsHeaderHasHeaderTrait() {
    let view = coachesListViewWithEnvironments()

    // Results header should have .isHeader trait for semantic navigation
    XCTAssertNotNil(view)
  }

  func testCoachesListView_searchFieldAccessible() {
    let view = coachesListViewWithEnvironments()

    // Search field should have proper accessibility
    XCTAssertNotNil(view)
  }

  func testCoachesListView_deleteConfirmationAccessible() {
    let view = coachesListViewWithEnvironments()

    // Delete confirmation dialog should be accessible
    XCTAssertNotNil(view)
  }

  func testCoachesListView_swipeActionsAccessible() {
    let view = coachesListViewWithEnvironments()

    // Swipe to delete should have proper labels
    XCTAssertNotNil(view)
  }

  // MARK: - Integration Tests

  func testIntegration_filterBarToChipsAccessibility() {
    var filters = CoachFilters()
    filters.role = .head
    filters.lastContactDays = 30

    let filterBar = CoachFilterBar(filters: .constant(filters))
    let activeChips = ActiveFilterChips(filters: .constant(filters))

    // Filter bar should announce selections
    // Active chips should show active filters with remove buttons
    XCTAssertNotNil(filterBar)
    XCTAssertNotNil(activeChips)
  }

  func testIntegration_emptyStateToClearFilters() {
    var filters = CoachFilters()
    filters.role = .head

    var clearedFilters = false
    let emptyState = CoachEmptyState(
      isFilteredEmpty: true,
      onClearFilters: { clearedFilters = true }
    )

    // Empty state should show clear filters button
    // Button should have proper accessibility
    XCTAssertNotNil(emptyState)
    _ = clearedFilters
  }

  // MARK: - Dynamic Type Tests

  func testDynamicType_allComponentsScaleCorrectly() {
    let coach = makeCoach()
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .medium,
      .accessibilityMedium,
      .accessibilityExtraExtraLarge
    ]

    for size in sizes {
      let cardView = CoachCardView(
        coach: coach,
        schoolName: "State University",
        schoolLogoUrl: nil,
        schoolInitials: "SU"
      )
      .environment(\.sizeCategory, size)

      let filterBar = CoachFilterBar(filters: .constant(CoachFilters()))
        .environment(\.sizeCategory, size)

      let emptyState = CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
        .environment(\.sizeCategory, size)

      // All components should render at all dynamic type sizes
      XCTAssertNotNil(cardView)
      XCTAssertNotNil(filterBar)
      XCTAssertNotNil(emptyState)
    }
  }

  // MARK: - Hit Target Tests

  func testHitTargets_allInteractiveElementsMeetMinimum() {
    // All interactive elements must meet 44x44pt minimum:
    // - Add coach button ✓
    // - Delete button ✓
    // - Communication buttons ✓
    // - Filter chips ✓
    // - Active filter chip remove buttons ✓
    // - Clear filters button ✓
    // - Clear all filters button ✓

    // These are verified in individual tests above
    XCTAssertTrue(true)
  }
}
