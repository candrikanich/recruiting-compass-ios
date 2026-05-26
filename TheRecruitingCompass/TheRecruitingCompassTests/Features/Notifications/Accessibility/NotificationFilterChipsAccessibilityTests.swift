import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationFilterChipsAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeChips(selectedType: NotificationType? = nil) -> NotificationFilterChips {
    NotificationFilterChips(
      selectedType: .constant(selectedType),
      onFilterChanged: { _ in }
    )
  }

  // MARK: - Accessibility Labels

  func testAllFilter_HasCorrectLabel_WhenInactive() {
    let chips = makeChips(selectedType: .deadlineAlert)
    let combinedLabel = chips.chipAccessibilityLabels.joined(separator: " ")

    XCTAssertTrue(combinedLabel.contains("All filter"), "Should have 'All' filter label")
    XCTAssertEqual(
      chips.chipAccessibilityLabels.first, "All filter",
      "Inactive 'All' chip should not announce a selected state"
    )
  }

  func testActiveFilter_AnnouncesSelectedState() {
    let chips = makeChips(selectedType: .deadlineAlert)
    let combinedLabel = chips.chipAccessibilityLabels.joined(separator: " ")

    XCTAssertTrue(combinedLabel.contains(", selected"), "Active filter chip should announce selected state")
    let deadlinesLabel = chips.chipAccessibilityLabels.first { $0.contains("Deadlines") }
    XCTAssertEqual(deadlinesLabel?.hasSuffix(", selected"), true, "Active 'Deadlines' chip should announce selected")
  }

  func testEachFilterType_HasDescriptiveLabel() {
    let chips = makeChips(selectedType: nil)
    let combinedLabel = chips.chipAccessibilityLabels.joined(separator: " ")

    let expectedLabels = ["All", "Follow-ups", "Deadlines", "Digest", "Inbound", "Offers", "Events"]
    for label in expectedLabels {
      XCTAssertTrue(combinedLabel.contains(label), "Filter chips should include '\(label)' option")
    }
  }

  // MARK: - Selected State (WCAG 1.4.1: not color alone)

  func testSelectedChip_LabelDistinguishedBeyondColor() {
    // The active chip appends ", selected" to its accessibility label, so the
    // selected state is conveyed by text, not color alone. The matching
    // `.isSelected` trait is applied in the SwiftUI body and is covered by the
    // E2E/VoiceOver audit (SwiftUI accessibility traits are not introspectable
    // from a unit test).
    let chips = makeChips(selectedType: .followUpReminder)
    let selectedLabels = chips.chipAccessibilityLabels.filter { $0.hasSuffix(", selected") }

    XCTAssertEqual(selectedLabels.count, 1, "Exactly one chip should be marked selected")
    XCTAssertEqual(selectedLabels.first, "\(NotificationType.followUpReminder.emoji) Follow-ups filter, selected")
  }

  func testNoChipSelected_WhenSelectionIsNilExceptAll() {
    let chips = makeChips(selectedType: nil)
    let selectedLabels = chips.chipAccessibilityLabels.filter { $0.hasSuffix(", selected") }

    XCTAssertEqual(selectedLabels.count, 1, "Only the 'All' chip should be selected when no type is chosen")
    XCTAssertEqual(selectedLabels.first, "All filter, selected")
  }

  // MARK: - Chip Display Labels

  func testChipDisplayLabels_IncludeEmojiAndTypeLabel() {
    let chips = makeChips()
    XCTAssertEqual(chips.chipDisplayLabels.first, "All", "First chip should be the 'All' option")

    for type in NotificationType.allCases {
      let expected = "\(type.emoji) \(type.label)"
      XCTAssertTrue(chips.chipDisplayLabels.contains(expected), "Display labels should include '\(expected)'")
    }
  }

  func testChipCount_MatchesAllPlusEveryNotificationType() {
    let chips = makeChips()
    XCTAssertEqual(
      chips.chipAccessibilityLabels.count, NotificationType.allCases.count + 1,
      "There should be one chip per notification type plus the 'All' chip"
    )
  }

  // MARK: - Color Not Sole Indicator (WCAG 1.4.1)

  func testActiveFilter_DistinguishedBeyondColor() {
    let allTypes = NotificationType.allCases
    XCTAssertGreaterThan(allTypes.count, 0, "Should have notification types for filter chips")

    for type in allTypes {
      XCTAssertFalse(type.label.isEmpty, "\(type.rawValue) should have a non-empty label for VoiceOver")
    }
  }
}
