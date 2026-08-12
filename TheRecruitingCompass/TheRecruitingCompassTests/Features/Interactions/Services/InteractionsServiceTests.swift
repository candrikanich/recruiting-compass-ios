import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InteractionsServiceTests: XCTestCase {
  nonisolated deinit {}
  var mockService: MockInteractionsService!

  override func setUp() {
    mockService = MockInteractionsService()
  }

  override func tearDown() {
    mockService = nil
  }

  // MARK: - Fetch Interactions Tests

  func testFetchInteractions_ReturnsAllInteractions() async throws {
    // Given
    let interactions = [
      createInteraction(id: "1"),
      createInteraction(id: "2"),
      createInteraction(id: "3")
    ]
    mockService.mockInteractions = interactions

    // When
    let result = try await mockService.fetchInteractions(familyUnitId: "family1")

    // Then
    XCTAssertEqual(result.count, 3)
  }

  func testFetchInteractions_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false

    // When/Then
    do {
      _ = try await mockService.fetchInteractions(familyUnitId: "family1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testFetchInteractionsForUser_FiltersCorrectly() async throws {
    // Given
    mockService.mockInteractions = [
      createInteraction(id: "1", loggedBy: "user1"),
      createInteraction(id: "2", loggedBy: "user2"),
      createInteraction(id: "3", loggedBy: "user1")
    ]

    // When
    let result = try await mockService.fetchInteractionsForUser(userId: "user1")

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertTrue(result.allSatisfy { $0.loggedBy == "user1" })
  }

  // MARK: - Fetch Interaction Detail Tests

  func testFetchInteraction_ReturnsInteraction() async throws {
    // Given
    let interaction = createInteraction(id: "test-id")
    mockService.mockInteractions = [interaction]

    // When
    let result = try await mockService.fetchInteraction(id: "test-id")

    // Then
    XCTAssertEqual(result.id, "test-id")
  }

  func testFetchInteraction_Throws404_WhenNotFound() async {
    // Given
    mockService.mockInteractions = []

    // When/Then
    do {
      _ = try await mockService.fetchInteraction(id: "nonexistent")
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.code, 404)
    }
  }

  func testFetchLoggedByUserName_ReturnsName() async throws {
    // When
    let name = try await mockService.fetchLoggedByUserName(userId: "user1")

    // Then
    XCTAssertEqual(name, "Test User")
  }

  // MARK: - Fetch Schools Tests

  func testFetchSchools_ReturnsAllSchools() async throws {
    // Given
    mockService.mockSchools = [
      createSchool(id: "1", name: "School 1"),
      createSchool(id: "2", name: "School 2")
    ]

    // When
    let result = try await mockService.fetchSchools(familyUnitId: "family1")

    // Then
    XCTAssertEqual(result.count, 2)
  }

  // MARK: - Fetch Coaches Tests

  func testFetchCoaches_ReturnsAllCoaches() async throws {
    // Given
    mockService.mockCoaches = [
      createCoach(id: "1"),
      createCoach(id: "2"),
      createCoach(id: "3")
    ]

    // When
    let result = try await mockService.fetchCoaches(familyUnitId: "family1")

    // Then
    XCTAssertEqual(result.count, 3)
  }

  // MARK: - Create Interaction Tests

  func testCreateInteraction_Success() async throws {
    // Given
    let request = InteractionCreateRequest(
      schoolId: "school1",
      coachId: "coach1",
      type: .email,
      direction: .outbound,
      occurredAt: Date(),
      subject: "Test",
      content: "Content",
      sentiment: .positive,
      loggedBy: "user1",
      familyUnitId: "family1"
    )

    // When
    let result = try await mockService.createInteraction(request)

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(mockService.createInteractionCallCount, 1)
    XCTAssertNotNil(mockService.lastCreatedInteractionRequest)
  }

  func testCreateInteraction_UsesProvidedMock() async throws {
    // Given
    let mockInteraction = createInteraction(id: "mock-id", subject: "Mock")
    mockService.mockCreatedInteraction = mockInteraction

    let request = InteractionCreateRequest(
      schoolId: "school1",
      coachId: "coach1",
      type: .email,
      direction: .outbound,
      occurredAt: Date(),
      subject: "Test",
      content: "Content",
      sentiment: nil,
      loggedBy: "user1",
      familyUnitId: "family1"
    )

    // When
    let result = try await mockService.createInteraction(request)

    // Then
    XCTAssertEqual(result.id, "mock-id")
    XCTAssertEqual(result.subject, "Mock")
  }

  // MARK: - Create Coach Tests

  func testCreateCoach_Success() async throws {
    // Given
    let request = CoachCreateRequest(
      schoolId: "school1",
      userId: "user1",
      familyUnitId: "family1",
      role: "assistant",
      firstName: "John",
      lastName: "Smith",
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // When
    let result = try await mockService.createCoach(request)

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(mockService.createCoachCallCount, 1)
    XCTAssertNotNil(mockService.lastCreatedCoachRequest)
  }

  func testCreateCoach_UsesProvidedMock() async throws {
    // Given
    let mockCoach = createCoach(id: "mock-id", firstName: "Mock", lastName: "Coach")
    mockService.mockCreatedCoach = mockCoach

    let request = CoachCreateRequest(
      schoolId: "school1",
      userId: "user1",
      familyUnitId: "family1",
      role: "assistant",
      firstName: "John",
      lastName: "Smith",
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // When
    let result = try await mockService.createCoach(request)

    // Then
    XCTAssertEqual(result.id, "mock-id")
    XCTAssertEqual(result.firstName, "Mock")
  }

  // MARK: - Upload Attachment Tests

  func testUploadAttachment_ReturnsURL() async throws {
    // Given
    let data = Data("test".utf8)

    // When
    let url = try await mockService.uploadAttachment(
      interactionId: "interaction1",
      fileName: "test.pdf",
      fileData: data
    )

    // Then
    XCTAssertTrue(url.contains("test.pdf"))
  }

  // MARK: - Delete Interaction Tests

  func testDeleteInteraction_Success() async throws {
    // Given
    mockService.mockInteractions = [createInteraction(id: "test-id")]

    // When
    try await mockService.deleteInteraction(id: "test-id")

    // Then
    XCTAssertEqual(mockService.deleteCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedId, "test-id")
    XCTAssertEqual(mockService.mockInteractions.count, 0)
  }

  func testDeleteInteraction_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false

    // When/Then
    do {
      try await mockService.deleteInteraction(id: "test-id")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - Cascade Delete Tests

  func testCascadeDeleteInteraction_Success() async throws {
    // Given
    mockService.mockInteractions = [createInteraction(id: "test-id")]

    // When
    let result = try await mockService.cascadeDeleteInteraction(id: "test-id")

    // Then
    XCTAssertEqual(mockService.cascadeDeleteCallCount, 1)
    XCTAssertEqual(mockService.lastCascadeDeletedId, "test-id")
    XCTAssertEqual(result.deletedInteractions, 1)
    XCTAssertEqual(result.deletedNotes, 2)
    XCTAssertEqual(mockService.mockInteractions.count, 0)
  }

  func testCascadeDeleteInteraction_ThrowsError_WhenServiceFails() async {
    // Given
    mockService.shouldSucceed = false

    // When/Then
    do {
      _ = try await mockService.cascadeDeleteInteraction(id: "test-id")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllState() {
    // Given
    mockService.mockInteractions = [createInteraction(id: "1")]
    mockService.mockSchools = [createSchool(id: "1", name: "School")]
    mockService.mockCoaches = [createCoach(id: "1")]
    mockService.deleteCallCount = 5
    mockService.createInteractionCallCount = 3

    // When
    mockService.reset()

    // Then
    XCTAssertTrue(mockService.mockInteractions.isEmpty)
    XCTAssertTrue(mockService.mockSchools.isEmpty)
    XCTAssertTrue(mockService.mockCoaches.isEmpty)
    XCTAssertEqual(mockService.deleteCallCount, 0)
    XCTAssertEqual(mockService.cascadeDeleteCallCount, 0)
    XCTAssertEqual(mockService.createInteractionCallCount, 0)
    XCTAssertEqual(mockService.createCoachCallCount, 0)
    XCTAssertNil(mockService.lastDeletedId)
    XCTAssertNil(mockService.lastCascadeDeletedId)
    XCTAssertNil(mockService.lastCreatedInteractionRequest)
    XCTAssertNil(mockService.lastCreatedCoachRequest)
  }

  // MARK: - Helper Methods

  private func createInteraction(
    id: String,
    subject: String? = "Subject",
    loggedBy: String = "user1"
  ) -> Interaction {
    Interaction(
      id: id,
      type: .email,
      direction: .outbound,
      schoolId: "school1",
      coachId: "coach1",
      subject: subject,
      content: "Content",
      sentiment: nil,
      occurredAt: ISO8601DateFormatter().string(from: Date()),
      loggedBy: loggedBy,
      attachments: nil,
      familyUnitId: "family1",
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: nil
    )
  }

  private func createSchool(id: String, name: String) -> School {
    School(
      id: id,
      userId: "user1",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: nil,
      conference: nil,
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "researching",
      statusChangedAt: nil,
      notes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "",
      updatedAt: ""
    )
  }

  private func createCoach(
    id: String,
    firstName: String = "First",
    lastName: String = "Last"
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: nil,
      phone: nil,
      position: "Assistant",
      schoolId: "school1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: nil,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }
}
