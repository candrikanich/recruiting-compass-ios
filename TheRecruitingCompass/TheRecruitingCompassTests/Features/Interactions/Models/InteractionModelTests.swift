import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InteractionModelTests: XCTestCase {

  // MARK: - Display Date Tests

  func testDisplayDate_UsesOccurredAt_WhenProvided() async {
    // Given
    let occurredAt = "2025-01-15T10:30:00.000Z"
    let createdAt = "2025-01-16T10:30:00.000Z"

    let interaction = createInteraction(id: "1", occurredAt: occurredAt, createdAt: createdAt)

    // When/Then
    let expectedDate = Interaction.iso8601Formatter.date(from: occurredAt)!
    XCTAssertEqual(interaction.displayDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 1.0)
  }

  func testDisplayDate_FallsBackToCreatedAt_WhenOccurredAtNil() async {
    // Given
    let createdAt = "2025-01-16T10:30:00.000Z"
    let interaction = createInteraction(id: "1", occurredAt: nil, createdAt: createdAt)

    // When/Then
    let expectedDate = Interaction.iso8601Formatter.date(from: createdAt)!
    XCTAssertEqual(interaction.displayDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 1.0)
  }

  func testDisplayDate_FallsBackToNow_WhenBothInvalid() {
    // Given
    let now = Date()
    let interaction = createInteraction(id: "1", occurredAt: "invalid-date", createdAt: "invalid-date")

    // When/Then
    XCTAssertEqual(interaction.displayDate.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 5.0)
  }

  // MARK: - Attachment Tests

  func testHasAttachments_ReturnsFalse_WhenNil() {
    // Given
    let interaction = createInteraction(attachments: nil)

    // Then
    XCTAssertFalse(interaction.hasAttachments)
    XCTAssertEqual(interaction.attachmentCount, 0)
  }

  func testHasAttachments_ReturnsFalse_WhenEmpty() {
    // Given
    let interaction = createInteraction(attachments: [])

    // Then
    XCTAssertFalse(interaction.hasAttachments)
    XCTAssertEqual(interaction.attachmentCount, 0)
  }

  func testHasAttachments_ReturnsTrue_WhenNotEmpty() {
    // Given
    let interaction = createInteraction(attachments: ["url1", "url2"])

    // Then
    XCTAssertTrue(interaction.hasAttachments)
    XCTAssertEqual(interaction.attachmentCount, 2)
  }

  // MARK: - Display Subject Tests

  func testDisplaySubject_ReturnsSubject_WhenProvided() {
    // Given
    let interaction = createInteraction(type: .email, subject: "Custom Subject")

    // Then
    XCTAssertEqual(interaction.displaySubject, "Custom Subject")
  }

  func testDisplaySubject_ReturnsTypeName_WhenSubjectNil() {
    // Given
    let interaction = createInteraction(type: .phoneCall, subject: nil)

    // Then
    XCTAssertEqual(interaction.displaySubject, "Phone Call")
  }

  // MARK: - InteractionType Tests

  func testInteractionType_DisplayNames() {
    XCTAssertEqual(InteractionType.email.displayName, "Email")
    XCTAssertEqual(InteractionType.phoneCall.displayName, "Phone Call")
    XCTAssertEqual(InteractionType.text.displayName, "Text")
    XCTAssertEqual(InteractionType.inPersonVisit.displayName, "In-Person Visit")
    XCTAssertEqual(InteractionType.virtualMeeting.displayName, "Virtual Meeting")
    XCTAssertEqual(InteractionType.camp.displayName, "Camp")
    XCTAssertEqual(InteractionType.showcase.displayName, "Showcase")
    XCTAssertEqual(InteractionType.tweet.displayName, "Tweet")
    XCTAssertEqual(InteractionType.directMessage.displayName, "Direct Message")
  }

  func testInteractionType_Icons() {
    XCTAssertEqual(InteractionType.email.iconName, "envelope.fill")
    XCTAssertEqual(InteractionType.phoneCall.iconName, "phone.fill")
    XCTAssertEqual(InteractionType.text.iconName, "bubble.left.fill")
    XCTAssertEqual(InteractionType.inPersonVisit.iconName, "person.2.fill")
    XCTAssertEqual(InteractionType.virtualMeeting.iconName, "video.fill")
    XCTAssertEqual(InteractionType.camp.iconName, "figure.run")
    XCTAssertEqual(InteractionType.showcase.iconName, "star.fill")
  }

  func testInteractionType_CaseIterable() {
    XCTAssertEqual(InteractionType.allCases.count, 9)
  }

  // MARK: - Direction Tests

  func testDirection_DisplayNames() {
    XCTAssertEqual(Direction.outbound.displayName, "Outbound")
    XCTAssertEqual(Direction.inbound.displayName, "Inbound")
  }

  func testDirection_Subtitles() {
    XCTAssertEqual(Direction.outbound.subtitle, "We initiated")
    XCTAssertEqual(Direction.inbound.subtitle, "They initiated")
  }

  // MARK: - Sentiment Tests

  func testSentiment_DisplayNames() {
    XCTAssertEqual(Sentiment.veryPositive.displayName, "Very Positive")
    XCTAssertEqual(Sentiment.positive.displayName, "Positive")
    XCTAssertEqual(Sentiment.neutral.displayName, "Neutral")
    XCTAssertEqual(Sentiment.negative.displayName, "Negative")
  }

  func testSentiment_IsPositive() {
    XCTAssertTrue(Sentiment.veryPositive.isPositive)
    XCTAssertTrue(Sentiment.positive.isPositive)
    XCTAssertFalse(Sentiment.neutral.isPositive)
    XCTAssertFalse(Sentiment.negative.isPositive)
  }

  // MARK: - Codable Tests

  func testInteraction_Codable() throws {
    // Given
    let interaction = createInteraction(
      id: "test-id",
      subject: "Test Subject",
      content: "Test Content"
    )

    // When
    let encoded = try JSONEncoder().encode(interaction)
    let decoded = try JSONDecoder().decode(Interaction.self, from: encoded)

    // Then
    XCTAssertEqual(decoded.id, interaction.id)
    XCTAssertEqual(decoded.type, interaction.type)
    XCTAssertEqual(decoded.direction, interaction.direction)
    XCTAssertEqual(decoded.subject, interaction.subject)
    XCTAssertEqual(decoded.content, interaction.content)
    XCTAssertEqual(decoded.schoolId, interaction.schoolId)
    XCTAssertEqual(decoded.coachId, interaction.coachId)
  }

  func testInteraction_SnakeCaseKeys() throws {
    // Given
    let json = """
    {
      "id": "1",
      "type": "email",
      "direction": "outbound",
      "school_id": "school1",
      "coach_id": "coach1",
      "subject": "Test",
      "content": "Content",
      "sentiment": "positive",
      "occurred_at": "2025-01-15T10:30:00.000Z",
      "logged_by": "user1",
      "attachments": ["url1"],
      "family_unit_id": "family1",
      "created_at": "2025-01-15T10:30:00.000Z",
      "updated_at": "2025-01-15T10:30:00.000Z"
    }
    """

    // When
    let data = json.data(using: .utf8)!
    let interaction = try JSONDecoder().decode(Interaction.self, from: data)

    // Then
    XCTAssertEqual(interaction.id, "1")
    XCTAssertEqual(interaction.schoolId, "school1")
    XCTAssertEqual(interaction.coachId, "coach1")
    XCTAssertEqual(interaction.loggedBy, "user1")
    XCTAssertEqual(interaction.familyUnitId, "family1")
  }

  // MARK: - Helper Methods

  private func createInteraction(
    id: String = "1",
    type: InteractionType = .email,
    direction: Direction = .outbound,
    subject: String? = "Subject",
    content: String? = "Content",
    sentiment: Sentiment? = nil,
    attachments: [String]? = nil,
    occurredAt: String? = nil,
    createdAt: String? = nil
  ) -> Interaction {
    Interaction(
      id: id,
      type: type,
      direction: direction,
      schoolId: "school1",
      coachId: "coach1",
      subject: subject,
      content: content,
      sentiment: sentiment,
      occurredAt: occurredAt,
      loggedBy: "user1",
      attachments: attachments,
      familyUnitId: "family1",
      createdAt: createdAt ?? ISO8601DateFormatter().string(from: Date()),
      updatedAt: nil
    )
  }
}
