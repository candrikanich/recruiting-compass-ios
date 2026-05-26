import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class OfferCardAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeCard(
    offer: Offer,
    schoolName: String = "Stanford University",
    isSelected: Bool = false
  ) -> OfferCard {
    OfferCard(
      offer: offer,
      schoolName: schoolName,
      isSelected: isSelected,
      onToggleSelection: {},
      onDelete: {}
    )
  }

  // MARK: - Accessibility Label

  func testCard_HasLabel_ContainingSchoolNameStatusAndType() {
    let offer = createOffer(status: .accepted, offerType: .fullRide, scholarshipAmount: 50000)
    let label = makeCard(offer: offer, schoolName: "Stanford University").cardAccessibilityLabel

    XCTAssertTrue(label.contains("Offer from Stanford University"), "Label should include 'Offer from [school]'")
    XCTAssertTrue(label.contains("Accepted"), "Label should include status")
    XCTAssertTrue(label.contains("Full Ride"), "Label should include offer type")
  }

  func testCard_HasLabel_ContainingAmountWhenPresent() {
    let offer = createOffer(scholarshipAmount: 25000)
    let label = makeCard(offer: offer, schoolName: "Michigan").cardAccessibilityLabel

    XCTAssertTrue(label.contains("$25,000"), "Label should include formatted amount")
  }

  func testCard_HasLabel_ContainingPercentageWhenPresent() {
    let offer = createOffer(scholarshipPercentage: 75)
    let label = makeCard(offer: offer, schoolName: "Duke").cardAccessibilityLabel

    XCTAssertTrue(label.contains("75%"), "Label should include percentage")
  }

  // MARK: - Deadline Urgency Conveyed as Text

  func testDeadlineUrgency_OverdueConveyedInLabel() {
    let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let offer = createOffer(deadlineDate: pastDate)

    XCTAssertNotNil(offer.daysUntilDeadline)
    XCTAssertLessThan(offer.daysUntilDeadline!, 0, "Days until deadline should be negative for overdue")

    let label = makeCard(offer: offer, schoolName: "Test School").cardAccessibilityLabel
    XCTAssertTrue(label.contains("Overdue"), "Label should include 'Overdue' text for past deadlines, not just color")
  }

  func testDeadlineUrgency_FutureDeadlineConveyedInLabel() {
    let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
    let offer = createOffer(deadlineDate: futureDate)

    XCTAssertNotNil(offer.daysUntilDeadline)
    XCTAssertGreaterThanOrEqual(offer.daysUntilDeadline!, 0)

    let label = makeCard(offer: offer, schoolName: "Test School").cardAccessibilityLabel
    XCTAssertTrue(label.contains("Deadline in"), "Label should include 'Deadline in N days' text")
    XCTAssertTrue(label.contains("day"), "Label should include day unit")
  }

  func testDeadlineUrgency_NoDeadlineOmitsFromLabel() {
    let offer = createOffer(deadlineDate: nil)

    let label = makeCard(offer: offer, schoolName: "Test School").cardAccessibilityLabel
    XCTAssertFalse(label.contains("Deadline"), "Label should not mention deadline when none set")
    XCTAssertFalse(label.contains("Overdue"), "Label should not mention overdue when no deadline")
  }

  // MARK: - Checkbox Accessibility

  func testCheckbox_HasCorrectLabel() {
    let card = makeCard(offer: createOffer(), schoolName: "Stanford")
    XCTAssertEqual(card.checkboxAccessibilityLabel, "Select for comparison")
  }

  func testCheckbox_SelectedState_HasCorrectValue() {
    let card = makeCard(offer: createOffer(), schoolName: "Stanford", isSelected: true)
    XCTAssertEqual(card.checkboxAccessibilityValue, "Selected", "Checkbox should announce 'Selected' when selected")
  }

  func testCheckbox_UnselectedState_HasCorrectValue() {
    let card = makeCard(offer: createOffer(), schoolName: "Stanford", isSelected: false)
    XCTAssertEqual(card.checkboxAccessibilityValue, "Not selected", "Checkbox should announce 'Not selected' when deselected")
  }

  // MARK: - Delete Button

  func testDeleteButton_HasLabel() {
    let card = makeCard(offer: createOffer(), schoolName: "Stanford")
    XCTAssertEqual(card.deleteAccessibilityLabel, "Delete offer from Stanford", "Delete button should have label with school name")
  }

  // MARK: - Decorative Icons Hidden
  //
  // The card hides decorative icons (calendar, clock) and the status color bar
  // via `.accessibilityHidden(true)` in the SwiftUI body. Those modifiers are
  // not introspectable from a unit test (SwiftUI does not expose its
  // accessibility tree to UIHostingController in unit tests), so the assertions
  // below exercise the underlying data the label relies on instead. The hidden
  // state is verified by the E2E/VoiceOver audit.

  func testStatusInfoConveyedViaLabelNotColorAlone() {
    let offer = createOffer(status: .accepted)
    let label = makeCard(offer: offer).cardAccessibilityLabel
    XCTAssertTrue(label.contains("Accepted"), "Status must be conveyed as text, not color alone")
  }

  // MARK: - Helper Methods

  private func createOffer(
    status: OfferStatus = .pending,
    offerType: OfferType = .scholarship,
    scholarshipAmount: Double? = nil,
    scholarshipPercentage: Int? = nil,
    deadlineDate: Date? = nil,
    notes: String? = nil
  ) -> Offer {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let deadlineString: String? = deadlineDate.map { dateFormatter.string(from: $0) }
    let now = ISO8601DateFormatter().string(from: Date())

    return Offer(
      id: UUID().uuidString,
      userId: "user1",
      schoolId: "school1",
      offerType: offerType,
      scholarshipAmount: scholarshipAmount,
      scholarshipPercentage: scholarshipPercentage,
      offerDate: dateFormatter.string(from: Date()),
      deadlineDate: deadlineString,
      status: status,
      conditions: nil,
      notes: notes,
      createdAt: now,
      updatedAt: now
    )
  }
}
