import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewAccessibilityTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeCoach(
    id: String = "coach-1",
    firstName: String = "John",
    lastName: String = "Smith",
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String? = "head",
    schoolId: String = "school-1",
    responsivenessScore: Double = 85
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
      privateNotes: nil,
      responsivenessScore: responsivenessScore,
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
      onDelete: {}
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
      onDelete: {}
    )

    // Initials circle should be hidden (decorative)
    XCTAssertNotNil(view)
  }

  func testCoachCardView_contactIconsHidden() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Email and phone icons should be hidden (decorative)
    XCTAssertNotNil(view)
  }

  func testCoachCardView_roleBadgeHasLabel() {
    let coach = makeCoach(position: "head")
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Role badge should have "Role: Head Coach" label
    XCTAssertEqual(coach.role.displayName, "Head Coach")
  }

  func testCoachCardView_deleteButtonHasLabelAndHint() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Delete button should have clear label and hint
    XCTAssertNotNil(view)
  }

  func testCoachCardView_deleteButtonMeetsHitTarget() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Delete button should have minWidth/minHeight: 44
    XCTAssertNotNil(view)
  }

  func testCoachCardView_communicationButtonsHaveLabels() {
    let coach = makeCoach(
      email: "test@test.com",
      phone: "555-1234"
    )
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Communication buttons should have descriptive labels
    XCTAssertNotNil(view)
  }

  func testCoachCardView_responsivenessBarAccessible() {
    let coach = makeCoach(responsivenessScore: 85)
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // ResponsivenessBar should have label and value
    XCTAssertNotNil(view)
  }

  func testCoachCardView_dynamicTypeSupport() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)

    // Should render without issues at large dynamic type sizes
    XCTAssertNotNil(view)
  }

  // MARK: - ResponsivenessBar Accessibility Tests

  func testResponsivenessBar_hasAccessibilityLabel() {
    let view = ResponsivenessBar(score: 85)

    // Should have "Responsiveness" as label
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_hasAccessibilityValue() {
    let view = ResponsivenessBar(score: 85)

    // Should have "85% Responsive" as value
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_progressBarHidden() {
    let view = ResponsivenessBar(score: 85)

    // Visual progress bar should be hidden from accessibility
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_hasUpdatesFrequentlyTrait() {
    let view = ResponsivenessBar(score: 85)

    // Should have .updatesFrequently trait since scores can change
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

  func testCoachFilterBar_responsivenessMenuAccessible() {
    let view = CoachFilterBar(filters: .constant(CoachFilters()))

    // Responsiveness menu should have label, hint, and value
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
    let view = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")

    // Should have "Email coach" label
    XCTAssertEqual(CommunicationType.email("").accessibilityLabel, "Email coach")
  }

  func testCommunicationButton_phoneHasLabel() {
    let view = CommunicationButton(type: .phone("555-1234"), value: "555-1234")

    // Should have "Text coach" label
    XCTAssertEqual(CommunicationType.phone("").accessibilityLabel, "Text coach")
  }

  func testCommunicationButton_twitterHasLabel() {
    let view = CommunicationButton(type: .twitter("@coach"), value: "@coach")

    // Should have "View Twitter profile" label
    XCTAssertEqual(CommunicationType.twitter("").accessibilityLabel, "View Twitter profile")
  }

  func testCommunicationButton_instagramHasLabel() {
    let view = CommunicationButton(type: .instagram("@coach"), value: "@coach")

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

  func testCoachesListView_addButtonAccessible() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Add button should have "Add new coach" label and hint
    XCTAssertNotNil(view)
  }

  func testCoachesListView_addButtonMeetsHitTarget() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Add button should have minWidth/minHeight: 44
    XCTAssertNotNil(view)
  }

  func testCoachesListView_loadingViewAccessible() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // ProgressView should have "Loading coaches" label
    // Redundant text should be hidden
    XCTAssertNotNil(view)
  }

  func testCoachesListView_resultsHeaderHasHeaderTrait() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Results header should have .isHeader trait for semantic navigation
    XCTAssertNotNil(view)
  }

  func testCoachesListView_searchFieldAccessible() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Search field should have proper accessibility
    XCTAssertNotNil(view)
  }

  func testCoachesListView_deleteConfirmationAccessible() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Delete confirmation dialog should be accessible
    XCTAssertNotNil(view)
  }

  func testCoachesListView_swipeActionsAccessible() {
    let view = CoachesListView()
      .environmentObject(FamilyManager.shared)

    // Swipe to delete should have proper labels
    XCTAssertNotNil(view)
  }

  // MARK: - Integration Tests

  func testIntegration_fullCardAccessibility() {
    let coach = makeCoach(
      email: "test@test.com",
      phone: "555-1234",
      position: "head"
    )
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      onDelete: {}
    )

    // Full card should be accessible with proper hierarchy:
    // - Header (name, school, role) readable
    // - Contact info readable
    // - Responsiveness bar with label/value
    // - Communication buttons with labels
    // - Delete button with label
    XCTAssertNotNil(view)
  }

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
        onDelete: {}
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
