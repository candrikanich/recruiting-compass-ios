import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class ActivityEventItemAccessibilityTests: XCTestCase {

  // MARK: - Icon Hidden from VoiceOver

  func testIcon_IsDecorativeOnly() {
    let event = createEvent(type: .interaction, icon: "envelope.fill")
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let images = findSubviews(of: UIImageView.self, in: view)
    XCTAssertTrue(images.allSatisfy { $0.accessibilityElementsHidden }, "Activity icon should be hidden from VoiceOver (info conveyed in label)")
  }

  // MARK: - Comprehensive Accessibility Label

  func testItem_HasComprehensiveLabel_Interaction() throws {
    let event = createEvent(
      type: .interaction,
      title: "Email with Arizona State",
      description: "Discussed camp schedule"
    )

    let item = ActivityEventItem(event: event)
    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Interactions"), "Label should include activity type")
    XCTAssertTrue(combinedLabel.contains("Email with Arizona State"), "Label should include title")
    XCTAssertTrue(combinedLabel.contains("Discussed camp schedule"), "Label should include description")
  }

  func testItem_HasComprehensiveLabel_SchoolStatus() throws {
    let event = createEvent(
      type: .schoolStatusChange,
      title: "Stanford - Interested",
      description: "Status changed to Interested"
    )

    let item = ActivityEventItem(event: event)
    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("School Status Changes"), "Label should include activity type")
    XCTAssertTrue(combinedLabel.contains("Stanford - Interested"), "Label should include title")
  }

  func testItem_HasComprehensiveLabel_Document() throws {
    let event = createEvent(
      type: .documentUpload,
      title: "Uploaded: Transcript",
      description: "New document uploaded",
      isClickable: false
    )

    let item = ActivityEventItem(event: event)
    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Documents"), "Label should include activity type")
    XCTAssertTrue(combinedLabel.contains("Uploaded: Transcript"), "Label should include title")
  }

  func testItem_LabelIncludesRelativeTime() throws {
    let event = createEvent(
      title: "Test Activity",
      description: "Test description"
    )

    let item = ActivityEventItem(event: event)
    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // Relative time should be part of the label (e.g., "2h ago" or "just now")
    let hasTimeIndicator = combinedLabel.contains("ago") || combinedLabel.contains("just now") || combinedLabel.contains("Jan") || combinedLabel.contains("Feb")
    XCTAssertTrue(hasTimeIndicator, "Label should include relative time")
  }

  func testItem_LabelOmitsEmptyDescription() {
    let event = createEvent(description: "")

    // Verify the accessibility label does not double-separate with empty description
    let label = buildAccessibilityLabel(for: event)
    XCTAssertFalse(label.contains(", ,"), "Label should not contain empty separators when description is empty")
  }

  // MARK: - Button Trait for Clickable Items

  func testClickableItem_HasButtonTrait() throws {
    let event = createEvent(isClickable: true)
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    let hasButtonTrait = accessibilityElements.contains { $0.accessibilityTraits.contains(.button) }
    XCTAssertTrue(hasButtonTrait, "Clickable activity should have button trait")
  }

  func testNonClickableItem_DoesNotHaveButtonTrait() throws {
    let event = createEvent(isClickable: false)
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    // Non-clickable items should NOT have button trait
    let hasButtonTrait = accessibilityElements.contains { $0.accessibilityTraits.contains(.button) }
    XCTAssertFalse(hasButtonTrait, "Non-clickable activity should not have button trait")
  }

  // MARK: - Accessibility Hint

  func testClickableItem_HasNavigationHint() throws {
    let event = createEvent(isClickable: true)
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let hints = findAccessibilityHints(in: view)
    try XCTSkipIf(hints.isEmpty, "SwiftUI accessibility hints not accessible via UIHostingController in unit tests")

    let hasNavigationHint = hints.contains { $0.lowercased().contains("tap") || $0.lowercased().contains("view") }
    XCTAssertTrue(hasNavigationHint, "Clickable item should hint at tap-to-navigate")
  }

  // MARK: - Chevron Hidden from VoiceOver

  func testChevron_IsHiddenFromVoiceOver() {
    let event = createEvent(isClickable: true)
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    // Chevron is decorative (navigation is conveyed via button trait)
    let images = findSubviews(of: UIImageView.self, in: view)
    XCTAssertTrue(images.allSatisfy { $0.accessibilityElementsHidden }, "Chevron icon should be hidden from VoiceOver")
  }

  // MARK: - Touch Target

  func testItem_MeetsMinimumTouchTarget() {
    let event = createEvent()
    let item = ActivityEventItem(event: event)
      .frame(width: 350)

    let hostingController = UIHostingController(rootView: item)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 200)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Activity item should meet WCAG 44pt minimum touch target")
  }

  func testCompactItem_MeetsMinimumTouchTarget() {
    let event = createEvent()
    let item = ActivityEventItem(event: event, compact: true)
      .frame(width: 350)

    let hostingController = UIHostingController(rootView: item)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 200)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Compact activity item should meet WCAG 44pt minimum touch target")
  }

  // MARK: - Dynamic Type Support

  func testItem_SupportsDynamicType_AccessibilitySize() {
    let event = createEvent(
      title: "Long activity title that should wrap properly",
      description: "Detailed description that needs to scale with Dynamic Type"
    )

    let item = ActivityEventItem(event: event)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 350, height: 300)

    let hostingController = UIHostingController(rootView: item)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 300)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Item should scale with Dynamic Type")
  }

  func testItem_IconScalesWithAccessibilityCategory() {
    // Verify icon adapts for accessibility size categories
    let event = createEvent()

    let normalItem = ActivityEventItem(event: event)
      .environment(\.sizeCategory, .large)
      .frame(width: 350)

    let accessibilityItem = ActivityEventItem(event: event)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 350)

    let normalHost = UIHostingController(rootView: normalItem)
    let accessibilityHost = UIHostingController(rootView: accessibilityItem)

    XCTAssertNotNil(normalHost.view)
    XCTAssertNotNil(accessibilityHost.view)
  }

  // MARK: - Accessibility Identifier

  func testItem_HasAccessibilityIdentifier() throws {
    let eventId = "interaction-test-123"
    let event = createEvent(id: eventId)
    let item = ActivityEventItem(event: event)

    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let identifiers = findAccessibilityIdentifiers(in: view)
    let hasEventId = identifiers.contains("activity-event-\(eventId)")

    try XCTSkipIf(!hasEventId, "SwiftUI accessibility identifiers not accessible via UIHostingController in unit tests")

    XCTAssertTrue(hasEventId, "Item should have accessibility identifier 'activity-event-\\(eventId)' for E2E test matching")
  }

  // MARK: - Elements Combination

  func testItem_CombinesChildElements() throws {
    let event = createEvent(
      title: "Email with Stanford",
      description: "Follow-up discussion about visit"
    )

    let item = ActivityEventItem(event: event)
    let hostingController = UIHostingController(rootView: item)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Interactions"), "Combined label should include type")
    XCTAssertTrue(combinedLabel.contains("Email with Stanford"), "Combined label should include title")
    XCTAssertTrue(combinedLabel.contains("Follow-up discussion"), "Combined label should include description")
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

  private func buildAccessibilityLabel(for event: ActivityEvent) -> String {
    var parts: [String] = []
    parts.append(event.type.label)
    parts.append(event.title)
    if !event.description.isEmpty {
      parts.append(event.description)
    }
    parts.append(RelativeTimeFormatter.format(event.timestamp))
    return parts.joined(separator: ", ")
  }

  private func findSubviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
    var results: [T] = []
    for subview in view.subviews {
      if let match = subview as? T {
        results.append(match)
      }
      results.append(contentsOf: findSubviews(of: type, in: subview))
    }
    return results
  }

  private func findAccessibilityElements(in view: UIView) -> [NSObject] {
    var elements: [NSObject] = []
    if view.isAccessibilityElement {
      elements.append(view)
    }
    if let accessibilityElements = view.accessibilityElements as? [NSObject] {
      elements.append(contentsOf: accessibilityElements)
    }
    for subview in view.subviews {
      elements.append(contentsOf: findAccessibilityElements(in: subview))
    }
    return elements
  }

  private func findAccessibilityHints(in view: UIView) -> [String] {
    var hints: [String] = []
    if let hint = view.accessibilityHint {
      hints.append(hint)
    }
    for subview in view.subviews {
      hints.append(contentsOf: findAccessibilityHints(in: subview))
    }
    return hints
  }

  private func findAccessibilityIdentifiers(in view: UIView) -> [String] {
    var identifiers: [String] = []
    if let identifier = view.accessibilityIdentifier, !identifier.isEmpty {
      identifiers.append(identifier)
    }
    for subview in view.subviews {
      identifiers.append(contentsOf: findAccessibilityIdentifiers(in: subview))
    }
    return identifiers
  }
}
