import XCTest
@testable import TheRecruitingCompass

final class ActivityEventModelTests: XCTestCase {

  // MARK: - ActivityEvent Identity Tests

  func testActivityEvent_Identifiable() {
    let event = makeEvent(id: "test-id")
    XCTAssertEqual(event.id, "test-id")
  }

  func testActivityEvent_UniqueIds() {
    let event1 = makeEvent(id: "event-1")
    let event2 = makeEvent(id: "event-2")
    XCTAssertNotEqual(event1.id, event2.id)
  }

  func testActivityEvent_InteractionPrefix() {
    let interaction = Interaction(
      id: "abc",
      type: .email,
      direction: .outbound,
      schoolId: nil,
      coachId: nil,
      subject: nil,
      content: nil,
      sentiment: nil,
      occurredAt: "2026-02-10T10:00:00.000Z",
      loggedBy: "user-1",
      attachments: nil,
      familyUnitId: "family-1",
      createdAt: "2026-02-10T10:00:00.000Z",
      updatedAt: nil
    )
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: nil)
    XCTAssertTrue(event.id.hasPrefix("interaction-"))
  }

  func testActivityEvent_StatusPrefix() {
    let change = SchoolStatusHistory(
      id: "xyz",
      schoolId: "s1",
      previousStatus: nil,
      newStatus: "researching",
      changedBy: "user-1",
      changedAt: Date(),
      createdAt: Date()
    )
    let event = ActivityEventFactory.fromStatusChange(change, schoolName: nil)
    XCTAssertTrue(event.id.hasPrefix("status-"))
  }

  func testActivityEvent_DocumentPrefix() {
    let doc = DocumentRecord(id: "123", title: "Test", type: nil, createdAt: "2026-02-10T10:00:00.000Z")
    let event = ActivityEventFactory.fromDocument(doc)
    XCTAssertTrue(event.id.hasPrefix("doc-"))
  }

  // MARK: - ActivityEvent Properties Tests

  func testActivityEvent_AllProperties() {
    let date = Date()
    let event = ActivityEvent(
      id: "test",
      type: .interaction,
      timestamp: date,
      title: "Test Title",
      description: "Test Description",
      icon: "envelope.fill",
      entityType: "school",
      entityId: "school-1",
      entityName: "UCLA",
      isClickable: true,
      clickUrl: "/schools/school-1"
    )

    XCTAssertEqual(event.id, "test")
    XCTAssertEqual(event.type, .interaction)
    XCTAssertEqual(event.timestamp, date)
    XCTAssertEqual(event.title, "Test Title")
    XCTAssertEqual(event.description, "Test Description")
    XCTAssertEqual(event.icon, "envelope.fill")
    XCTAssertEqual(event.entityType, "school")
    XCTAssertEqual(event.entityId, "school-1")
    XCTAssertEqual(event.entityName, "UCLA")
    XCTAssertTrue(event.isClickable)
    XCTAssertEqual(event.clickUrl, "/schools/school-1")
  }

  func testActivityEvent_NilOptionals() {
    let event = makeEvent(entityType: nil, entityId: nil, entityName: nil, clickUrl: nil)
    XCTAssertNil(event.entityType)
    XCTAssertNil(event.entityId)
    XCTAssertNil(event.entityName)
    XCTAssertNil(event.clickUrl)
  }

  // MARK: - ActivityEventType Tests

  func testActivityEventType_Equality() {
    XCTAssertEqual(ActivityEventType.interaction, ActivityEventType.interaction)
    XCTAssertNotEqual(ActivityEventType.interaction, ActivityEventType.documentUpload)
  }

  func testActivityEventType_AllCasesCount() {
    XCTAssertEqual(ActivityEventType.allCases.count, 3)
  }

  func testActivityEventType_AllCasesContains() {
    let cases = ActivityEventType.allCases
    XCTAssertTrue(cases.contains(.interaction))
    XCTAssertTrue(cases.contains(.schoolStatusChange))
    XCTAssertTrue(cases.contains(.documentUpload))
  }

  func testActivityEventType_RawValues() {
    XCTAssertEqual(ActivityEventType.interaction.rawValue, "interaction")
    XCTAssertEqual(ActivityEventType.schoolStatusChange.rawValue, "school_status_change")
    XCTAssertEqual(ActivityEventType.documentUpload.rawValue, "document_upload")
  }

  func testActivityEventType_Labels() {
    XCTAssertEqual(ActivityEventType.interaction.label, "Interactions")
    XCTAssertEqual(ActivityEventType.schoolStatusChange.label, "School Status Changes")
    XCTAssertEqual(ActivityEventType.documentUpload.label, "Documents")
  }

  func testActivityEventType_InitFromRawValue() {
    XCTAssertEqual(ActivityEventType(rawValue: "interaction"), .interaction)
    XCTAssertEqual(ActivityEventType(rawValue: "school_status_change"), .schoolStatusChange)
    XCTAssertEqual(ActivityEventType(rawValue: "document_upload"), .documentUpload)
    XCTAssertNil(ActivityEventType(rawValue: "invalid"))
  }

  // MARK: - ActivityDateRange Tests

  func testActivityDateRange_AllCasesCount() {
    XCTAssertEqual(ActivityDateRange.allCases.count, 4)
  }

  func testActivityDateRange_Labels() {
    XCTAssertEqual(ActivityDateRange.all.label, "All Time")
    XCTAssertEqual(ActivityDateRange.week.label, "Last 7 Days")
    XCTAssertEqual(ActivityDateRange.month.label, "Last 30 Days")
    XCTAssertEqual(ActivityDateRange.quarter.label, "Last 90 Days")
  }

  func testActivityDateRange_DaysAgo() {
    XCTAssertNil(ActivityDateRange.all.daysAgo)
    XCTAssertEqual(ActivityDateRange.week.daysAgo, 7)
    XCTAssertEqual(ActivityDateRange.month.daysAgo, 30)
    XCTAssertEqual(ActivityDateRange.quarter.daysAgo, 90)
  }

  func testActivityDateRange_RawValues() {
    XCTAssertEqual(ActivityDateRange.all.rawValue, "all")
    XCTAssertEqual(ActivityDateRange.week.rawValue, "week")
    XCTAssertEqual(ActivityDateRange.month.rawValue, "month")
    XCTAssertEqual(ActivityDateRange.quarter.rawValue, "quarter")
  }

  func testActivityDateRange_InitFromRawValue() {
    XCTAssertEqual(ActivityDateRange(rawValue: "all"), .all)
    XCTAssertEqual(ActivityDateRange(rawValue: "week"), .week)
    XCTAssertEqual(ActivityDateRange(rawValue: "month"), .month)
    XCTAssertEqual(ActivityDateRange(rawValue: "quarter"), .quarter)
    XCTAssertNil(ActivityDateRange(rawValue: "invalid"))
  }

  // MARK: - ActivityIcon Tests

  func testActivityIcon_AllInteractionTypes() {
    let expected: [String: String] = [
      "email": "envelope.fill",
      "phone_call": "phone.fill",
      "text": "bubble.left.fill",
      "in_person_visit": "person.2.fill",
      "virtual_meeting": "video.fill",
      "camp": "figure.run",
      "showcase": "star.fill",
      "tweet": "bubble.left.fill",
      "dm": "paperplane.fill"
    ]

    for (type, expectedIcon) in expected {
      XCTAssertEqual(
        ActivityIcon.forInteractionType(type),
        expectedIcon,
        "Icon mismatch for \(type)"
      )
    }
  }

  func testActivityIcon_UnknownTypes() {
    XCTAssertEqual(ActivityIcon.forInteractionType("unknown"), ActivityIcon.defaultInteraction)
    XCTAssertEqual(ActivityIcon.forInteractionType(""), ActivityIcon.defaultInteraction)
    XCTAssertEqual(ActivityIcon.forInteractionType("fax"), ActivityIcon.defaultInteraction)
    XCTAssertEqual(ActivityIcon.forInteractionType("smoke_signal"), ActivityIcon.defaultInteraction)
  }

  func testActivityIcon_Constants() {
    XCTAssertEqual(ActivityIcon.defaultInteraction, "pencil.line")
    XCTAssertEqual(ActivityIcon.schoolStatus, "mappin.circle.fill")
    XCTAssertEqual(ActivityIcon.document, "doc.fill")
  }

  func testActivityIcon_InteractionIconsDict() {
    XCTAssertEqual(ActivityIcon.interactionIcons.count, 9)
  }

  // MARK: - DocumentRecord Tests

  func testDocumentRecord_Identifiable() {
    let doc = DocumentRecord(id: "doc-1", title: "Test", type: "pdf", createdAt: "2026-01-01T00:00:00Z")
    XCTAssertEqual(doc.id, "doc-1")
  }

  func testDocumentRecord_AllProperties() {
    let doc = DocumentRecord(
      id: "doc-1",
      title: "My Transcript",
      type: "pdf",
      createdAt: "2026-02-10T10:00:00Z"
    )
    XCTAssertEqual(doc.title, "My Transcript")
    XCTAssertEqual(doc.type, "pdf")
    XCTAssertEqual(doc.createdAt, "2026-02-10T10:00:00Z")
  }

  func testDocumentRecord_NilType() {
    let doc = DocumentRecord(id: "doc-1", title: "Test", type: nil, createdAt: "2026-01-01T00:00:00Z")
    XCTAssertNil(doc.type)
  }

  func testDocumentRecord_JSONDecoding() throws {
    let json = """
    {"id":"d1","title":"Resume.pdf","type":"pdf","created_at":"2026-02-10T10:00:00Z"}
    """.data(using: .utf8)!

    let doc = try JSONDecoder().decode(DocumentRecord.self, from: json)
    XCTAssertEqual(doc.id, "d1")
    XCTAssertEqual(doc.title, "Resume.pdf")
    XCTAssertEqual(doc.type, "pdf")
    XCTAssertEqual(doc.createdAt, "2026-02-10T10:00:00Z")
  }

  func testDocumentRecord_JSONDecodingWithNullType() throws {
    let json = """
    {"id":"d1","title":"Resume","type":null,"created_at":"2026-02-10T10:00:00Z"}
    """.data(using: .utf8)!

    let doc = try JSONDecoder().decode(DocumentRecord.self, from: json)
    XCTAssertNil(doc.type)
  }

  func testDocumentRecord_JSONDecodingWithMissingType() throws {
    let json = """
    {"id":"d1","title":"Resume","created_at":"2026-02-10T10:00:00Z"}
    """.data(using: .utf8)!

    let doc = try JSONDecoder().decode(DocumentRecord.self, from: json)
    XCTAssertNil(doc.type)
  }

  func testDocumentRecord_RoundTrip() throws {
    let original = DocumentRecord(id: "d1", title: "Test", type: "pdf", createdAt: "2026-02-10T10:00:00Z")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DocumentRecord.self, from: data)
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.title, original.title)
    XCTAssertEqual(decoded.type, original.type)
    XCTAssertEqual(decoded.createdAt, original.createdAt)
  }

  // MARK: - ActivityEventFactory Tests

  func testFactory_InteractionTitle_IncludesTypeAndSchool() {
    let interaction = makeInteraction(type: .phoneCall)
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "Stanford")
    XCTAssertEqual(event.title, "Phone Call with Stanford")
  }

  func testFactory_InteractionTitle_AllTypes() {
    for type in InteractionType.allCases {
      let interaction = makeInteraction(type: type)
      let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "Test")
      XCTAssertTrue(event.title.contains(type.displayName), "Title missing type for \(type)")
      XCTAssertTrue(event.title.contains("Test"), "Title missing school for \(type)")
    }
  }

  func testFactory_StatusChange_FormatsStatus() {
    let testCases: [(String, String)] = [
      ("researching", "Researching"),
      ("actively_recruiting", "Actively Recruiting"),
      ("committed", "Committed"),
      ("no_longer_interested", "No Longer Interested")
    ]

    for (raw, expected) in testCases {
      let change = SchoolStatusHistory(
        id: "s1",
        schoolId: "school-1",
        previousStatus: nil,
        newStatus: raw,
        changedBy: "user-1",
        changedAt: Date(),
        createdAt: Date()
      )
      let event = ActivityEventFactory.fromStatusChange(change, schoolName: "Test")
      XCTAssertTrue(
        event.title.contains(expected),
        "Expected '\(expected)' in title, got '\(event.title)'"
      )
    }
  }

  func testFactory_Document_TitlePrefix() {
    let doc = DocumentRecord(id: "d1", title: "Transcript.pdf", type: "pdf", createdAt: "2026-02-10T10:00:00.000Z")
    let event = ActivityEventFactory.fromDocument(doc)
    XCTAssertTrue(event.title.hasPrefix("Uploaded: "))
    XCTAssertEqual(event.title, "Uploaded: Transcript.pdf")
  }

  func testFactory_Document_DescriptionWithType() {
    let doc = DocumentRecord(id: "d1", title: "Test", type: "resume", createdAt: "2026-02-10T10:00:00.000Z")
    let event = ActivityEventFactory.fromDocument(doc)
    XCTAssertEqual(event.description, "New resume uploaded")
  }

  func testFactory_Document_DescriptionWithoutType() {
    let doc = DocumentRecord(id: "d1", title: "Test", type: nil, createdAt: "2026-02-10T10:00:00.000Z")
    let event = ActivityEventFactory.fromDocument(doc)
    XCTAssertEqual(event.description, "New document uploaded")
  }

  // MARK: - Sorting Tests

  func testSorting_NewestFirst() {
    let now = Date()
    let events = [
      makeEvent(id: "old", timestamp: now.addingTimeInterval(-7200)),
      makeEvent(id: "new", timestamp: now),
      makeEvent(id: "mid", timestamp: now.addingTimeInterval(-3600))
    ]

    let sorted = events.sorted { $0.timestamp > $1.timestamp }
    XCTAssertEqual(sorted.map(\.id), ["new", "mid", "old"])
  }

  func testSorting_SameTimestamp_StableOrder() {
    let date = Date()
    let events = [
      makeEvent(id: "a", timestamp: date),
      makeEvent(id: "b", timestamp: date),
      makeEvent(id: "c", timestamp: date)
    ]

    let sorted = events.sorted { $0.timestamp > $1.timestamp }
    XCTAssertEqual(sorted.count, 3)
  }

  // MARK: - Helpers

  private func makeEvent(
    id: String = "test",
    type: ActivityEventType = .interaction,
    timestamp: Date = Date(),
    title: String = "Test",
    description: String = "Description",
    icon: String = "star",
    entityType: String? = nil,
    entityId: String? = nil,
    entityName: String? = nil,
    isClickable: Bool = false,
    clickUrl: String? = nil
  ) -> ActivityEvent {
    ActivityEvent(
      id: id,
      type: type,
      timestamp: timestamp,
      title: title,
      description: description,
      icon: icon,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      isClickable: isClickable,
      clickUrl: clickUrl
    )
  }

  private func makeInteraction(
    id: String = "i1",
    type: InteractionType = .email,
    schoolId: String? = "school-1",
    content: String? = "Test content",
    subject: String? = "Test subject"
  ) -> Interaction {
    Interaction(
      id: id,
      type: type,
      direction: .outbound,
      schoolId: schoolId,
      coachId: nil,
      subject: subject,
      content: content,
      sentiment: nil,
      occurredAt: "2026-02-10T10:00:00.000Z",
      loggedBy: "user-1",
      attachments: nil,
      familyUnitId: "family-1",
      createdAt: "2026-02-10T10:00:00.000Z",
      updatedAt: nil
    )
  }
}
