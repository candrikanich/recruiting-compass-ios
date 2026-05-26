import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionCardAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeCard(
    interaction: Interaction,
    schoolName: String? = "Stanford",
    coachName: String? = "Coach Smith"
  ) -> InteractionCard {
    InteractionCard(
      interaction: interaction,
      schoolName: schoolName,
      coachName: coachName
    )
  }

  // MARK: - Comprehensive Accessibility Label

  func testCard_HasComprehensiveAccessibilityLabel_FullContext() {
    let interaction = createInteraction(
      type: .email,
      direction: .outbound,
      subject: "Follow-up on Camp Visit",
      sentiment: .veryPositive
    )
    let label = makeCard(
      interaction: interaction,
      schoolName: "Stanford University",
      coachName: "Coach Smith"
    ).accessibilityLabel

    XCTAssertTrue(label.contains("Email"), "Label should include type")
    XCTAssertTrue(label.contains("Outbound"), "Label should include direction")
    XCTAssertTrue(label.contains("Follow-up on Camp Visit"), "Label should include subject")
    XCTAssertTrue(label.contains("Stanford University"), "Label should include school")
    XCTAssertTrue(label.contains("Coach Smith"), "Label should include coach")
    XCTAssertTrue(label.contains("Very Positive"), "Label should include sentiment")
  }

  func testCard_HasComprehensiveAccessibilityLabel_MinimalContext() {
    let interaction = createInteraction(
      type: .phoneCall,
      direction: .inbound,
      subject: nil,
      sentiment: nil
    )
    let label = makeCard(interaction: interaction, schoolName: nil, coachName: nil)
      .accessibilityLabel

    XCTAssertTrue(label.contains("Phone Call"), "Label should include type")
    XCTAssertTrue(label.contains("Inbound"), "Label should include direction")
  }

  func testCard_AccessibilityLabel_IncludesSchoolContext() {
    let interaction = createInteraction()
    let label = makeCard(
      interaction: interaction,
      schoolName: "Stanford University",
      coachName: nil
    ).accessibilityLabel

    XCTAssertTrue(
      label.contains("at Stanford University"),
      "Label should include school with 'at' preposition"
    )
  }

  func testCard_AccessibilityLabel_IncludesCoachContext() {
    let interaction = createInteraction()
    let label = makeCard(interaction: interaction, schoolName: nil, coachName: "Coach Smith")
      .accessibilityLabel

    XCTAssertTrue(
      label.contains("with Coach Smith"),
      "Label should include coach with 'with' preposition"
    )
  }

  func testCard_CombinesChildElements() {
    let interaction = createInteraction(
      subject: "Follow-up Email",
      content: "Thank you for your time"
    )
    let label = makeCard(
      interaction: interaction,
      schoolName: "Stanford University",
      coachName: "Coach Smith"
    ).accessibilityLabel

    XCTAssertTrue(label.contains("Email"), "Combined label should include type")
    XCTAssertTrue(label.contains("Follow-up Email"), "Combined label should include subject")
    XCTAssertTrue(label.contains("Stanford University"), "Combined label should include school")
  }

  // MARK: - Accessibility Hint
  //
  // The card applies `.accessibilityAddTraits(.isButton)` and the hint in its
  // SwiftUI body; trait application is not introspectable from a unit test
  // (covered by E2E/VoiceOver). The hint string itself is verified here.

  func testCard_HasAccessibilityHint() {
    let card = makeCard(interaction: createInteraction())
    XCTAssertEqual(card.accessibilityHint, "Tap to view details")
  }

  // MARK: - Attachment Indicator

  func testAttachmentIndicator_HasCorrectFormat_Singular() {
    let interaction = createInteraction(attachments: ["file1.pdf"])
    XCTAssertTrue(interaction.hasAttachments, "Interaction should have attachments")
    XCTAssertEqual(interaction.attachmentCount, 1, "Interaction should have 1 attachment")

    let indicator = AttachmentIndicator(count: interaction.attachmentCount)
    XCTAssertEqual(indicator.accessibilityLabel, "1 attachment")
  }

  func testAttachmentIndicator_HasCorrectFormat_Plural() {
    let interaction = createInteraction(attachments: ["file1.pdf", "file2.jpg", "file3.doc"])
    XCTAssertTrue(interaction.hasAttachments, "Interaction should have attachments")
    XCTAssertEqual(interaction.attachmentCount, 3, "Interaction should have 3 attachments")

    let indicator = AttachmentIndicator(count: interaction.attachmentCount)
    XCTAssertEqual(indicator.accessibilityLabel, "3 attachments")
  }

  // MARK: - Decorative Icons Hidden
  //
  // The card hides decorative icons (type icon, calendar, paperclip) via
  // `.accessibilityHidden(true)` in the SwiftUI body. Those modifiers are not
  // introspectable from a unit test, so the assertions below exercise the data
  // the label relies on instead. Hidden state is verified by the E2E/VoiceOver
  // audit.

  func testTypeInfoConveyedViaLabelNotIconAlone() {
    let interaction = createInteraction(type: .email)
    let label = makeCard(interaction: interaction).accessibilityLabel
    XCTAssertTrue(
      label.contains("Email"),
      "Interaction type must be conveyed as text, not icon alone"
    )
  }

  func testDateConveyedViaLabelNotIconAlone() {
    let interaction = createInteraction()
    let label = makeCard(interaction: interaction).accessibilityLabel
    let expectedDate = DateFormatting.mediumDateShortTime(interaction.displayDate)
    XCTAssertTrue(
      label.contains(expectedDate),
      "Date must be conveyed as text, not the calendar icon alone"
    )
  }

  // MARK: - Helper Methods

  private func createInteraction(
    type: InteractionType = .email,
    direction: Direction = .outbound,
    subject: String? = "Test Subject",
    content: String? = "Test content",
    sentiment: Sentiment? = .veryPositive,
    attachments: [String]? = nil
  ) -> Interaction {
    Interaction(
      id: UUID().uuidString,
      type: type,
      direction: direction,
      schoolId: "school1",
      coachId: "coach1",
      subject: subject,
      content: content,
      sentiment: sentiment,
      occurredAt: ISO8601DateFormatter().string(from: Date()),
      loggedBy: "user1",
      attachments: attachments,
      familyUnitId: "family1",
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }
}
