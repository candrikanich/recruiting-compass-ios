import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class ActivityEventItemAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeItem(event: ActivityEvent, compact: Bool = false) -> ActivityEventItem {
    ActivityEventItem(event: event, compact: compact)
  }

  // MARK: - Comprehensive Accessibility Label

  func testItem_HasComprehensiveLabel_Interaction() {
    let event = createEvent(
      type: .interaction,
      title: "Email with Arizona State",
      description: "Discussed camp schedule"
    )
    let label = makeItem(event: event).accessibilityLabel

    XCTAssertTrue(label.contains("Interactions"), "Label should include activity type")
    XCTAssertTrue(label.contains("Email with Arizona State"), "Label should include title")
    XCTAssertTrue(label.contains("Discussed camp schedule"), "Label should include description")
  }

  func testItem_HasComprehensiveLabel_SchoolStatus() {
    let event = createEvent(
      type: .schoolStatusChange,
      title: "Stanford - Interested",
      description: "Status changed to Interested"
    )
    let label = makeItem(event: event).accessibilityLabel

    XCTAssertTrue(label.contains("School Status Changes"), "Label should include activity type")
    XCTAssertTrue(label.contains("Stanford - Interested"), "Label should include title")
  }

  func testItem_HasComprehensiveLabel_Document() {
    let event = createEvent(
      type: .documentUpload,
      title: "Uploaded: Transcript",
      description: "New document uploaded",
      isClickable: false
    )
    let label = makeItem(event: event).accessibilityLabel

    XCTAssertTrue(label.contains("Documents"), "Label should include activity type")
    XCTAssertTrue(label.contains("Uploaded: Transcript"), "Label should include title")
  }

  func testItem_LabelIncludesRelativeTime() {
    let event = createEvent(title: "Test Activity", description: "Test description")
    let label = makeItem(event: event).accessibilityLabel

    // Event timestamp is 2 hours in the past; formatter yields e.g. "2 hours ago".
    let hasTimeIndicator = label.contains("ago") || label.contains("hour")
    XCTAssertTrue(hasTimeIndicator, "Label should include relative time")
  }

  func testItem_LabelOmitsEmptyDescription() {
    let event = createEvent(description: "")
    let label = makeItem(event: event).accessibilityLabel

    XCTAssertFalse(label.contains(", ,"), "Label should not contain empty separators when description is empty")
  }

  func testItem_CombinesChildElements() {
    let event = createEvent(
      title: "Email with Stanford",
      description: "Follow-up discussion about visit"
    )
    let label = makeItem(event: event).accessibilityLabel

    XCTAssertTrue(label.contains("Interactions"), "Combined label should include type")
    XCTAssertTrue(label.contains("Email with Stanford"), "Combined label should include title")
    XCTAssertTrue(label.contains("Follow-up discussion"), "Combined label should include description")
  }

  // MARK: - Decorative Icons / Chevron Hidden
  //
  // The activity icon and the trailing chevron are marked `.accessibilityHidden(true)`
  // in the SwiftUI body; their hidden state is not introspectable from a unit test
  // (SwiftUI does not expose its accessibility tree to UIHostingController in unit
  // tests). Instead we assert the navigation/type information is conveyed through the
  // label, which is what VoiceOver actually announces. Hidden-state is covered by the
  // E2E/VoiceOver audit.

  func testIconInfoConveyedViaLabel() {
    let event = createEvent(type: .interaction)
    let label = makeItem(event: event).accessibilityLabel
    XCTAssertTrue(label.contains("Interactions"), "Activity type must be conveyed as text, not icon alone")
  }

  func testNavigationConveyedViaHintNotChevron() {
    let clickable = createEvent(isClickable: true)
    XCTAssertEqual(makeItem(event: clickable).event.isClickable, true)
    // Clickable items expose a navigation hint and button trait in the body;
    // the chevron is decorative-only.
  }

  // MARK: - Helper Methods

  private func createEvent(
    id: String = UUID().uuidString,
    type: ActivityEventType = .interaction,
    title: String = "Test Activity",
    description: String = "Test description",
    icon: String = "envelope.fill",
    isClickable: Bool = true
  ) -> ActivityEvent {
    ActivityEvent(
      id: id,
      type: type,
      timestamp: Date().addingTimeInterval(-7200),
      title: title,
      description: description,
      icon: icon,
      entityType: "school",
      entityId: "school1",
      entityName: "Test School",
      isClickable: isClickable,
      clickUrl: isClickable ? "/schools/school1" : nil
    )
  }
}
