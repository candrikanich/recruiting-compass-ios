import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ActivityFeedServiceTests: XCTestCase {
  nonisolated deinit {}
  var mockService: MockActivityFeedService!

  override func setUp() {
    super.setUp()
    mockService = MockActivityFeedService()
  }

  override func tearDown() {
    mockService = nil
    super.tearDown()
  }

  // MARK: - Fetch Interactions Tests

  func testFetchInteractions_ReturnsAllInteractions() async throws {
    // Given
    mockService.mockInteractions = [
      createInteraction(id: "1"),
      createInteraction(id: "2"),
      createInteraction(id: "3")
    ]

    // When
    let result = try await mockService.fetchInteractions(userId: "user-1")

    // Then
    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchInteractionsUserId, "user-1")
  }

  func testFetchInteractions_ReturnsEmptyWhenNone() async throws {
    // Given
    mockService.mockInteractions = []

    // When
    let result = try await mockService.fetchInteractions(userId: "user-1")

    // Then
    XCTAssertTrue(result.isEmpty)
  }

  func testFetchInteractions_ThrowsOnFailure() async {
    // Given
    mockService.shouldThrowOnInteractions = true

    // When/Then
    do {
      _ = try await mockService.fetchInteractions(userId: "user-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    }
  }

  func testFetchInteractions_PassesCorrectUserId() async throws {
    // When
    _ = try await mockService.fetchInteractions(userId: "specific-user-id")

    // Then
    XCTAssertEqual(mockService.lastFetchInteractionsUserId, "specific-user-id")
  }

  // MARK: - Fetch Status Changes Tests

  func testFetchStatusChanges_ReturnsAllChanges() async throws {
    // Given
    mockService.mockStatusChanges = [
      createStatusChange(id: "1"),
      createStatusChange(id: "2")
    ]

    // When
    let result = try await mockService.fetchStatusChanges(userId: "user-1")

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(mockService.fetchStatusChangesCallCount, 1)
    XCTAssertEqual(mockService.lastFetchStatusChangesUserId, "user-1")
  }

  func testFetchStatusChanges_ReturnsEmptyWhenNone() async throws {
    // Given
    mockService.mockStatusChanges = []

    // When
    let result = try await mockService.fetchStatusChanges(userId: "user-1")

    // Then
    XCTAssertTrue(result.isEmpty)
  }

  func testFetchStatusChanges_ThrowsOnFailure() async {
    // Given
    mockService.shouldThrowOnStatusChanges = true

    // When/Then
    do {
      _ = try await mockService.fetchStatusChanges(userId: "user-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.fetchStatusChangesCallCount, 1)
    }
  }

  // MARK: - Fetch Documents Tests

  func testFetchDocuments_ReturnsAllDocuments() async throws {
    // Given
    mockService.mockDocuments = [
      createDocument(id: "1"),
      createDocument(id: "2"),
      createDocument(id: "3")
    ]

    // When
    let result = try await mockService.fetchDocuments(userId: "user-1")

    // Then
    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(mockService.fetchDocumentsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchDocumentsUserId, "user-1")
  }

  func testFetchDocuments_ReturnsEmptyWhenNone() async throws {
    // Given
    mockService.mockDocuments = []

    // When
    let result = try await mockService.fetchDocuments(userId: "user-1")

    // Then
    XCTAssertTrue(result.isEmpty)
  }

  func testFetchDocuments_ThrowsOnFailure() async {
    // Given
    mockService.shouldThrowOnDocuments = true

    // When/Then
    do {
      _ = try await mockService.fetchDocuments(userId: "user-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.fetchDocumentsCallCount, 1)
    }
  }

  // MARK: - Fetch School Names (Hydration) Tests

  func testFetchSchoolNames_ReturnsMappedNames() async throws {
    // Given
    mockService.mockSchoolNames = [
      "school-1": "Arizona State",
      "school-2": "UCLA"
    ]

    // When
    let result = try await mockService.fetchSchoolNames(schoolIds: ["school-1", "school-2"])

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result["school-1"], "Arizona State")
    XCTAssertEqual(result["school-2"], "UCLA")
    XCTAssertEqual(mockService.fetchSchoolNamesCallCount, 1)
    XCTAssertEqual(mockService.lastFetchSchoolNamesIds, ["school-1", "school-2"])
  }

  func testFetchSchoolNames_ReturnsEmptyForNoIds() async throws {
    // When
    let result = try await mockService.fetchSchoolNames(schoolIds: [])

    // Then
    XCTAssertTrue(result.isEmpty)
  }

  func testFetchSchoolNames_ThrowsOnFailure() async {
    // Given
    mockService.shouldThrowOnSchoolNames = true

    // When/Then
    do {
      _ = try await mockService.fetchSchoolNames(schoolIds: ["school-1"])
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual(mockService.fetchSchoolNamesCallCount, 1)
    }
  }

  func testFetchSchoolNames_HandlesPartialResults() async throws {
    // Given: only one of two requested schools has a name
    mockService.mockSchoolNames = ["school-1": "Arizona State"]

    // When
    let result = try await mockService.fetchSchoolNames(schoolIds: ["school-1", "school-missing"])

    // Then
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result["school-1"], "Arizona State")
    XCTAssertNil(result["school-missing"])
  }

  // MARK: - Service Integration: All Three Sources

  func testFetchAllSources_IndependentCalls() async throws {
    // Given
    mockService.mockInteractions = [createInteraction(id: "i1")]
    mockService.mockStatusChanges = [createStatusChange(id: "s1")]
    mockService.mockDocuments = [createDocument(id: "d1")]

    // When
    let interactions = try await mockService.fetchInteractions(userId: "user-1")
    let statusChanges = try await mockService.fetchStatusChanges(userId: "user-1")
    let documents = try await mockService.fetchDocuments(userId: "user-1")

    // Then
    XCTAssertEqual(interactions.count, 1)
    XCTAssertEqual(statusChanges.count, 1)
    XCTAssertEqual(documents.count, 1)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockService.fetchStatusChangesCallCount, 1)
    XCTAssertEqual(mockService.fetchDocumentsCallCount, 1)
  }

  func testPartialFailure_InteractionsFailOthersSucceed() async throws {
    // Given
    mockService.shouldThrowOnInteractions = true
    mockService.mockStatusChanges = [createStatusChange(id: "s1")]
    mockService.mockDocuments = [createDocument(id: "d1")]

    // When: interactions fail
    do {
      _ = try await mockService.fetchInteractions(userId: "user-1")
      XCTFail("Expected error")
    } catch {
      // Expected
    }

    // Then: other sources still work
    let statusChanges = try await mockService.fetchStatusChanges(userId: "user-1")
    let documents = try await mockService.fetchDocuments(userId: "user-1")
    XCTAssertEqual(statusChanges.count, 1)
    XCTAssertEqual(documents.count, 1)
  }

  func testPartialFailure_StatusChangesFailOthersSucceed() async throws {
    // Given
    mockService.mockInteractions = [createInteraction(id: "i1")]
    mockService.shouldThrowOnStatusChanges = true
    mockService.mockDocuments = [createDocument(id: "d1")]

    // When: status changes fail
    do {
      _ = try await mockService.fetchStatusChanges(userId: "user-1")
      XCTFail("Expected error")
    } catch {
      // Expected
    }

    // Then: other sources still work
    let interactions = try await mockService.fetchInteractions(userId: "user-1")
    let documents = try await mockService.fetchDocuments(userId: "user-1")
    XCTAssertEqual(interactions.count, 1)
    XCTAssertEqual(documents.count, 1)
  }

  func testPartialFailure_DocumentsFailOthersSucceed() async throws {
    // Given
    mockService.mockInteractions = [createInteraction(id: "i1")]
    mockService.mockStatusChanges = [createStatusChange(id: "s1")]
    mockService.shouldThrowOnDocuments = true

    // When: documents fail
    do {
      _ = try await mockService.fetchDocuments(userId: "user-1")
      XCTFail("Expected error")
    } catch {
      // Expected
    }

    // Then: other sources still work
    let interactions = try await mockService.fetchInteractions(userId: "user-1")
    let statusChanges = try await mockService.fetchStatusChanges(userId: "user-1")
    XCTAssertEqual(interactions.count, 1)
    XCTAssertEqual(statusChanges.count, 1)
  }

  func testAllSourcesFail_ThrowsIndependently() async {
    // Given
    mockService.shouldThrowOnInteractions = true
    mockService.shouldThrowOnStatusChanges = true
    mockService.shouldThrowOnDocuments = true

    // When/Then: each call throws independently
    do {
      _ = try await mockService.fetchInteractions(userId: "user-1")
      XCTFail("Expected error")
    } catch { }

    do {
      _ = try await mockService.fetchStatusChanges(userId: "user-1")
      XCTFail("Expected error")
    } catch { }

    do {
      _ = try await mockService.fetchDocuments(userId: "user-1")
      XCTFail("Expected error")
    } catch { }

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockService.fetchStatusChangesCallCount, 1)
    XCTAssertEqual(mockService.fetchDocumentsCallCount, 1)
  }

  // MARK: - School Name Hydration Integration

  func testSchoolNameHydration_CollectsIdsFromInteractionsAndStatusChanges() async throws {
    // Given: interactions and status changes have school IDs
    let interaction1 = createInteraction(id: "i1", schoolId: "school-1")
    let interaction2 = createInteraction(id: "i2", schoolId: "school-2")
    let interaction3 = createInteraction(id: "i3", schoolId: "school-1") // duplicate
    let statusChange = createStatusChange(id: "s1", schoolId: "school-3")

    mockService.mockInteractions = [interaction1, interaction2, interaction3]
    mockService.mockStatusChanges = [statusChange]
    mockService.mockSchoolNames = [
      "school-1": "Arizona State",
      "school-2": "UCLA",
      "school-3": "Stanford"
    ]

    // When: fetch all data
    let interactions = try await mockService.fetchInteractions(userId: "user-1")
    let statusChanges = try await mockService.fetchStatusChanges(userId: "user-1")

    // Collect unique school IDs (as the ViewModel would)
    var schoolIds = Set<String>()
    for interaction in interactions {
      if let schoolId = interaction.schoolId {
        schoolIds.insert(schoolId)
      }
    }
    for change in statusChanges {
      schoolIds.insert(change.schoolId)
    }

    let schoolNames = try await mockService.fetchSchoolNames(
      schoolIds: Array(schoolIds)
    )

    // Then
    XCTAssertEqual(schoolIds.count, 3)
    XCTAssertEqual(schoolNames.count, 3)
    XCTAssertEqual(schoolNames["school-1"], "Arizona State")
    XCTAssertEqual(schoolNames["school-2"], "UCLA")
    XCTAssertEqual(schoolNames["school-3"], "Stanford")
  }

  func testSchoolNameHydration_HandlesInteractionsWithNoSchoolId() async throws {
    // Given: interaction with nil school ID
    let interaction = createInteraction(id: "i1", schoolId: nil)
    mockService.mockInteractions = [interaction]

    // When
    let interactions = try await mockService.fetchInteractions(userId: "user-1")
    let schoolIds = interactions.compactMap(\.schoolId)

    // Then
    XCTAssertTrue(schoolIds.isEmpty)
  }

  // MARK: - Multiple Calls Tracking

  func testMultipleFetchCalls_IncrementCallCount() async throws {
    // When
    _ = try await mockService.fetchInteractions(userId: "user-1")
    _ = try await mockService.fetchInteractions(userId: "user-2")
    _ = try await mockService.fetchInteractions(userId: "user-3")

    // Then
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 3)
    XCTAssertEqual(mockService.lastFetchInteractionsUserId, "user-3")
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllState() async throws {
    // Given: populate state
    mockService.mockInteractions = [createInteraction(id: "1")]
    mockService.mockStatusChanges = [createStatusChange(id: "1")]
    mockService.mockDocuments = [createDocument(id: "1")]
    mockService.mockSchoolNames = ["s1": "School"]
    mockService.shouldThrowOnInteractions = true
    mockService.shouldThrowOnStatusChanges = true
    mockService.shouldThrowOnDocuments = true
    mockService.shouldThrowOnSchoolNames = true
    mockService.fetchInteractionsCallCount = 5
    mockService.fetchStatusChangesCallCount = 3
    mockService.fetchDocumentsCallCount = 2
    mockService.fetchSchoolNamesCallCount = 1
    mockService.lastFetchInteractionsUserId = "old-user"
    mockService.lastFetchStatusChangesUserId = "old-user"
    mockService.lastFetchDocumentsUserId = "old-user"
    mockService.lastFetchSchoolNamesIds = ["old-school"]

    // When
    mockService.reset()

    // Then
    XCTAssertTrue(mockService.mockInteractions.isEmpty)
    XCTAssertTrue(mockService.mockStatusChanges.isEmpty)
    XCTAssertTrue(mockService.mockDocuments.isEmpty)
    XCTAssertTrue(mockService.mockSchoolNames.isEmpty)
    XCTAssertFalse(mockService.shouldThrowOnInteractions)
    XCTAssertFalse(mockService.shouldThrowOnStatusChanges)
    XCTAssertFalse(mockService.shouldThrowOnDocuments)
    XCTAssertFalse(mockService.shouldThrowOnSchoolNames)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 0)
    XCTAssertEqual(mockService.fetchStatusChangesCallCount, 0)
    XCTAssertEqual(mockService.fetchDocumentsCallCount, 0)
    XCTAssertEqual(mockService.fetchSchoolNamesCallCount, 0)
    XCTAssertNil(mockService.lastFetchInteractionsUserId)
    XCTAssertNil(mockService.lastFetchStatusChangesUserId)
    XCTAssertNil(mockService.lastFetchDocumentsUserId)
    XCTAssertNil(mockService.lastFetchSchoolNamesIds)
  }

  func testReset_AllowsSubsequentCalls() async throws {
    // Given: error state
    mockService.shouldThrowOnInteractions = true
    do {
      _ = try await mockService.fetchInteractions(userId: "user-1")
    } catch { }

    // When: reset
    mockService.reset()
    mockService.mockInteractions = [createInteraction(id: "new")]

    // Then: succeeds after reset
    let result = try await mockService.fetchInteractions(userId: "user-1")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, "new")
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
  }

  // MARK: - ActivityEventFactory Integration Tests

  func testFactoryCreatesEventFromInteraction_WithSchoolName() {
    // Given
    let interaction = createInteraction(id: "i1", schoolId: "school-1")

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "Arizona State")

    // Then
    XCTAssertEqual(event.id, "interaction-i1")
    XCTAssertEqual(event.type, .interaction)
    XCTAssertTrue(event.title.contains("Arizona State"))
    XCTAssertTrue(event.isClickable)
    XCTAssertEqual(event.clickUrl, "/schools/school-1")
    XCTAssertEqual(event.entityType, "school")
    XCTAssertEqual(event.entityId, "school-1")
    XCTAssertEqual(event.entityName, "Arizona State")
  }

  func testFactoryCreatesEventFromInteraction_WithNilSchoolName() {
    // Given
    let interaction = createInteraction(id: "i1", schoolId: "school-1")

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: nil)

    // Then
    XCTAssertTrue(event.title.contains("Unknown School"))
    XCTAssertEqual(event.entityName, "Unknown School")
  }

  func testFactoryCreatesEventFromInteraction_UsesContent() {
    // Given
    let interaction = createInteraction(
      id: "i1",
      content: "Discussed upcoming camp schedule and roster spots"
    )

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then
    XCTAssertEqual(event.description, "Discussed upcoming camp schedule and roster spots")
  }

  func testFactoryCreatesEventFromInteraction_TruncatesLongContent() {
    // Given
    let longContent = String(repeating: "A", count: 100)
    let interaction = createInteraction(id: "i1", content: longContent)

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then
    XCTAssertEqual(event.description.count, 50)
  }

  func testFactoryCreatesEventFromInteraction_FallsBackToSubject() {
    // Given
    let interaction = createInteraction(id: "i1", content: nil, subject: "Camp Follow-up")

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then
    XCTAssertEqual(event.description, "Camp Follow-up")
  }

  func testFactoryCreatesEventFromInteraction_FallsBackToEmptyString() {
    // Given
    let interaction = createInteraction(id: "i1", content: nil, subject: nil)

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then
    XCTAssertEqual(event.description, "")
  }

  func testFactoryCreatesEventFromInteraction_CorrectIcon() {
    // Given
    let emailInteraction = createInteraction(id: "i1", type: .email)
    let phoneInteraction = createInteraction(id: "i2", type: .phoneCall)
    let campInteraction = createInteraction(id: "i3", type: .camp)

    // When
    let emailEvent = ActivityEventFactory.fromInteraction(emailInteraction, schoolName: "UCLA")
    let phoneEvent = ActivityEventFactory.fromInteraction(phoneInteraction, schoolName: "UCLA")
    let campEvent = ActivityEventFactory.fromInteraction(campInteraction, schoolName: "UCLA")

    // Then
    XCTAssertEqual(emailEvent.icon, "envelope.fill")
    XCTAssertEqual(phoneEvent.icon, "phone.fill")
    XCTAssertEqual(campEvent.icon, "figure.run")
  }

  func testFactoryCreatesEventFromInteraction_UsesOccurredAt() {
    // Given
    let occurredAt = "2026-02-10T10:00:00.000Z"
    let createdAt = "2026-02-01T08:00:00.000Z"
    let interaction = createInteraction(
      id: "i1",
      occurredAt: occurredAt,
      createdAt: createdAt
    )

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then: should use occurredAt, not createdAt
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let expectedDate = formatter.date(from: occurredAt)!
    XCTAssertEqual(
      event.timestamp.timeIntervalSince1970,
      expectedDate.timeIntervalSince1970,
      accuracy: 1.0
    )
  }

  func testFactoryCreatesEventFromInteraction_FallsBackToCreatedAt() {
    // Given
    let createdAt = "2026-02-01T08:00:00.000Z"
    let interaction = createInteraction(
      id: "i1",
      occurredAt: nil,
      createdAt: createdAt
    )

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: "UCLA")

    // Then
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let expectedDate = formatter.date(from: createdAt)!
    XCTAssertEqual(
      event.timestamp.timeIntervalSince1970,
      expectedDate.timeIntervalSince1970,
      accuracy: 1.0
    )
  }

  func testFactoryCreatesEventFromInteraction_NilSchoolIdMakesNoClickUrl() {
    // Given
    let interaction = createInteraction(id: "i1", schoolId: nil)

    // When
    let event = ActivityEventFactory.fromInteraction(interaction, schoolName: nil)

    // Then
    XCTAssertTrue(event.isClickable)
    XCTAssertNil(event.clickUrl)
  }

  func testFactoryCreatesEventFromStatusChange() {
    // Given
    let statusChange = createStatusChange(
      id: "s1",
      schoolId: "school-1",
      newStatus: "actively_recruiting",
      notes: "Started conversations"
    )

    // When
    let event = ActivityEventFactory.fromStatusChange(statusChange, schoolName: "Stanford")

    // Then
    XCTAssertEqual(event.id, "status-s1")
    XCTAssertEqual(event.type, .schoolStatusChange)
    XCTAssertTrue(event.title.contains("Stanford"))
    XCTAssertTrue(event.title.contains("Actively Recruiting"))
    XCTAssertEqual(event.description, "Started conversations")
    XCTAssertEqual(event.icon, ActivityIcon.schoolStatus)
    XCTAssertTrue(event.isClickable)
    XCTAssertEqual(event.clickUrl, "/schools/school-1")
    XCTAssertEqual(event.entityType, "school")
    XCTAssertEqual(event.entityId, "school-1")
    XCTAssertEqual(event.entityName, "Stanford")
  }

  func testFactoryCreatesEventFromStatusChange_NilSchoolName() {
    // Given
    let statusChange = createStatusChange(id: "s1")

    // When
    let event = ActivityEventFactory.fromStatusChange(statusChange, schoolName: nil)

    // Then
    XCTAssertTrue(event.title.contains("Unknown School"))
    XCTAssertEqual(event.entityName, "Unknown School")
  }

  func testFactoryCreatesEventFromStatusChange_NilNotesUsesDefaultDescription() {
    // Given
    let statusChange = createStatusChange(id: "s1", newStatus: "committed", notes: nil)

    // When
    let event = ActivityEventFactory.fromStatusChange(statusChange, schoolName: "UCLA")

    // Then
    XCTAssertEqual(event.description, "Status changed to Committed")
  }

  func testFactoryCreatesEventFromStatusChange_FormatsUnderscoreStatus() {
    // Given
    let statusChange = createStatusChange(id: "s1", newStatus: "actively_recruiting")

    // When
    let event = ActivityEventFactory.fromStatusChange(statusChange, schoolName: "UCLA")

    // Then
    XCTAssertTrue(event.title.contains("Actively Recruiting"))
  }

  func testFactoryCreatesEventFromDocument() {
    // Given
    let document = createDocument(id: "d1", title: "Transcript.pdf", type: "pdf")

    // When
    let event = ActivityEventFactory.fromDocument(document)

    // Then
    XCTAssertEqual(event.id, "doc-d1")
    XCTAssertEqual(event.type, .documentUpload)
    XCTAssertEqual(event.title, "Uploaded: Transcript.pdf")
    XCTAssertEqual(event.description, "New pdf uploaded")
    XCTAssertEqual(event.icon, ActivityIcon.document)
    XCTAssertFalse(event.isClickable)
    XCTAssertNil(event.clickUrl)
    XCTAssertEqual(event.entityType, "document")
    XCTAssertEqual(event.entityId, "d1")
    XCTAssertEqual(event.entityName, "Transcript.pdf")
  }

  func testFactoryCreatesEventFromDocument_NilType() {
    // Given
    let document = createDocument(id: "d1", title: "Resume", type: nil)

    // When
    let event = ActivityEventFactory.fromDocument(document)

    // Then
    XCTAssertEqual(event.description, "New document uploaded")
  }

  // MARK: - Merging and Sorting Tests

  func testMergedEvents_SortByTimestampDescending() {
    // Given: events from all 3 sources at different times
    let now = Date()
    let oneHourAgo = now.addingTimeInterval(-3600)
    let twoHoursAgo = now.addingTimeInterval(-7200)
    let threeHoursAgo = now.addingTimeInterval(-10800)

    let events: [ActivityEvent] = [
      ActivityEvent(
        id: "interaction-1",
        type: .interaction,
        timestamp: twoHoursAgo,
        title: "Email with UCLA",
        description: "Test",
        icon: "envelope.fill",
        entityType: "school",
        entityId: "s1",
        entityName: "UCLA",
        isClickable: true,
        clickUrl: "/schools/s1"
      ),
      ActivityEvent(
        id: "status-1",
        type: .schoolStatusChange,
        timestamp: oneHourAgo,
        title: "Stanford - Committed",
        description: "Status changed",
        icon: "mappin.circle.fill",
        entityType: "school",
        entityId: "s2",
        entityName: "Stanford",
        isClickable: true,
        clickUrl: "/schools/s2"
      ),
      ActivityEvent(
        id: "doc-1",
        type: .documentUpload,
        timestamp: threeHoursAgo,
        title: "Uploaded: Transcript",
        description: "New pdf uploaded",
        icon: "doc.fill",
        entityType: "document",
        entityId: "d1",
        entityName: "Transcript",
        isClickable: false,
        clickUrl: nil
      )
    ]

    // When
    let sorted = events.sorted { $0.timestamp > $1.timestamp }

    // Then: newest first
    XCTAssertEqual(sorted[0].id, "status-1")
    XCTAssertEqual(sorted[1].id, "interaction-1")
    XCTAssertEqual(sorted[2].id, "doc-1")
  }

  func testMergedEvents_MixedTypesPreserveChronologicalOrder() {
    // Given
    let events = (0..<10).map { i in
      ActivityEvent(
        id: "event-\(i)",
        type: ActivityEventType.allCases[i % 3],
        timestamp: Date().addingTimeInterval(Double(-i * 3600)),
        title: "Event \(i)",
        description: "Description \(i)",
        icon: "star",
        entityType: nil,
        entityId: nil,
        entityName: nil,
        isClickable: false,
        clickUrl: nil
      )
    }

    // When
    let sorted = events.sorted { $0.timestamp > $1.timestamp }

    // Then: events are in order from newest (event-0) to oldest (event-9)
    for i in 0..<sorted.count {
      XCTAssertEqual(sorted[i].id, "event-\(i)")
    }
  }

  // MARK: - ActivityIcon Tests

  func testActivityIconMapping_AllInteractionTypes() {
    XCTAssertEqual(ActivityIcon.forInteractionType("email"), "envelope.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("phone_call"), "phone.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("text"), "bubble.left.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("in_person_visit"), "person.2.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("virtual_meeting"), "video.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("camp"), "figure.run")
    XCTAssertEqual(ActivityIcon.forInteractionType("showcase"), "star.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("tweet"), "bubble.left.fill")
    XCTAssertEqual(ActivityIcon.forInteractionType("dm"), "paperplane.fill")
  }

  func testActivityIconMapping_UnknownTypeReturnsDefault() {
    XCTAssertEqual(ActivityIcon.forInteractionType("unknown"), ActivityIcon.defaultInteraction)
    XCTAssertEqual(ActivityIcon.forInteractionType(""), ActivityIcon.defaultInteraction)
    XCTAssertEqual(ActivityIcon.forInteractionType("fax"), ActivityIcon.defaultInteraction)
  }

  func testActivityIconConstants() {
    XCTAssertEqual(ActivityIcon.defaultInteraction, "pencil.line")
    XCTAssertEqual(ActivityIcon.schoolStatus, "mappin.circle.fill")
    XCTAssertEqual(ActivityIcon.document, "doc.fill")
  }

  // MARK: - ActivityEventType Tests

  func testActivityEventType_Labels() {
    XCTAssertEqual(ActivityEventType.interaction.label, "Interactions")
    XCTAssertEqual(ActivityEventType.schoolStatusChange.label, "School Status Changes")
    XCTAssertEqual(ActivityEventType.documentUpload.label, "Documents")
  }

  func testActivityEventType_RawValues() {
    XCTAssertEqual(ActivityEventType.interaction.rawValue, "interaction")
    XCTAssertEqual(ActivityEventType.schoolStatusChange.rawValue, "school_status_change")
    XCTAssertEqual(ActivityEventType.documentUpload.rawValue, "document_upload")
  }

  func testActivityEventType_CaseIterable() {
    XCTAssertEqual(ActivityEventType.allCases.count, 3)
  }

  // MARK: - ActivityDateRange Tests

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

  func testActivityDateRange_CaseIterable() {
    XCTAssertEqual(ActivityDateRange.allCases.count, 4)
  }

  // MARK: - DocumentRecord Tests

  func testDocumentRecord_DecodesFromJSON() throws {
    // Given
    let json = """
    {
      "id": "doc-1",
      "title": "Transcript.pdf",
      "type": "pdf",
      "created_at": "2026-02-10T10:00:00Z"
    }
    """.data(using: .utf8)!

    // When
    let document = try JSONDecoder().decode(DocumentRecord.self, from: json)

    // Then
    XCTAssertEqual(document.id, "doc-1")
    XCTAssertEqual(document.title, "Transcript.pdf")
    XCTAssertEqual(document.type, "pdf")
    XCTAssertEqual(document.createdAt, "2026-02-10T10:00:00Z")
  }

  func testDocumentRecord_DecodesWithNilType() throws {
    // Given
    let json = """
    {
      "id": "doc-1",
      "title": "Resume",
      "type": null,
      "created_at": "2026-02-10T10:00:00Z"
    }
    """.data(using: .utf8)!

    // When
    let document = try JSONDecoder().decode(DocumentRecord.self, from: json)

    // Then
    XCTAssertNil(document.type)
  }

  func testDocumentRecord_EncodesCorrectly() throws {
    // Given
    let document = DocumentRecord(
      id: "doc-1",
      title: "Test",
      type: "pdf",
      createdAt: "2026-02-10T10:00:00Z"
    )

    // When
    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(DocumentRecord.self, from: data)

    // Then
    XCTAssertEqual(decoded.id, document.id)
    XCTAssertEqual(decoded.title, document.title)
    XCTAssertEqual(decoded.type, document.type)
    XCTAssertEqual(decoded.createdAt, document.createdAt)
  }

  // MARK: - Service Initialization

  func testServiceImplInitializes() {
    let service = ActivityFeedServiceImpl(supabaseManager: SupabaseManager.shared)
    XCTAssertNotNil(service)
  }

  // MARK: - Helper Methods

  private func createInteraction(
    id: String,
    type: InteractionType = .email,
    schoolId: String? = "school-1",
    content: String? = "Test content",
    subject: String? = "Test Subject",
    occurredAt: String? = "2026-02-10T10:00:00.000Z",
    createdAt: String = "2026-02-09T08:00:00.000Z",
    loggedBy: String = "user-1"
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
      occurredAt: occurredAt,
      loggedBy: loggedBy,
      attachments: nil,
      familyUnitId: "family-1",
      createdAt: createdAt,
      updatedAt: nil
    )
  }

  private func createStatusChange(
    id: String,
    schoolId: String = "school-1",
    newStatus: String = "researching",
    notes: String? = "Test notes"
  ) -> SchoolStatusHistory {
    SchoolStatusHistory(
      id: id,
      schoolId: schoolId,
      previousStatus: nil,
      newStatus: newStatus,
      changedBy: "user-1",
      changedAt: Date(),
      notes: notes,
      createdAt: Date()
    )
  }

  private func createDocument(
    id: String,
    title: String = "Test Document",
    type: String? = "pdf"
  ) -> DocumentRecord {
    DocumentRecord(
      id: id,
      title: title,
      type: type,
      createdAt: "2026-02-10T10:00:00.000Z"
    )
  }
}
