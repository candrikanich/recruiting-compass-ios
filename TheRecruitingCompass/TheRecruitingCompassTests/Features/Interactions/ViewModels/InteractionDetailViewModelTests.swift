import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InteractionDetailViewModelTests: XCTestCase {
  var viewModel: InteractionDetailViewModel!
  var mockService: MockInteractionsService!
  var mockAuthManager: MockAuthManager!

  override func setUp() async throws {
    mockService = MockInteractionsService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.user = createUser(id: "user1")

    viewModel = InteractionDetailViewModel(
      interactionId: "interaction1",
      familyUnitId: "family1",
      interactionsService: mockService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
  }

  // MARK: - Initialization Tests

  func testInit_SetsLoadingStateFalse() {
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertFalse(viewModel.isDeleting)
  }

  func testInit_SetsInteractionNil() {
    XCTAssertNil(viewModel.interaction)
    XCTAssertNil(viewModel.school)
    XCTAssertNil(viewModel.coach)
  }

  // MARK: - Load Interaction Tests

  func testLoadInteraction_Success() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]
    mockService.mockSchools = [createSchool(id: "school1")]
    mockService.mockCoaches = [createCoach(id: "coach1")]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertNotNil(viewModel.interaction)
    XCTAssertEqual(viewModel.interaction?.id, "interaction1")
    XCTAssertNotNil(viewModel.school)
    XCTAssertNotNil(viewModel.coach)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadInteraction_ServiceError_ShowsError() async {
    // Given
    mockService.shouldSucceed = false

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertNil(viewModel.interaction)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load") ?? false)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadInteraction_LoadsSchoolWhenPresent() async {
    // Given
    let interaction = createInteraction(id: "interaction1", schoolId: "school1")
    let school = createSchool(id: "school1", name: "Stanford")
    mockService.mockInteractions = [interaction]
    mockService.mockSchools = [school]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertNotNil(viewModel.school)
    XCTAssertEqual(viewModel.school?.id, "school1")
    XCTAssertEqual(viewModel.school?.name, "Stanford")
  }

  func testLoadInteraction_LoadsCoachWhenPresent() async {
    // Given
    let interaction = createInteraction(id: "interaction1", coachId: "coach1")
    let coach = createCoach(id: "coach1", firstName: "John", lastName: "Smith")
    mockService.mockInteractions = [interaction]
    mockService.mockCoaches = [coach]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertNotNil(viewModel.coach)
    XCTAssertEqual(viewModel.coach?.id, "coach1")
    XCTAssertEqual(viewModel.coach?.firstName, "John")
  }

  func testLoadInteraction_SkipsDuplicateLoad() async {
    // Given
    mockService.mockInteractions = [createInteraction(id: "interaction1")]

    // When (trigger load twice)
    await viewModel.loadInteraction()

    // Simulate already loading
    viewModel.isLoading = true
    await viewModel.loadInteraction()

    // Then (still only one interaction loaded)
    XCTAssertNotNil(viewModel.interaction)
  }

  // MARK: - Permission Tests

  func testIsOwner_TrueWhenUserIsLoggedBy() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertTrue(viewModel.isOwner)
  }

  func testIsOwner_FalseWhenUserIsNotLoggedBy() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user2")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertFalse(viewModel.isOwner)
  }

  func testCanDelete_TrueWhenOwner() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertTrue(viewModel.canDelete)
  }

  func testCanDelete_FalseWhenNotOwner() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user2")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertFalse(viewModel.canDelete)
  }

  func testCanExport_TrueWhenInteractionLoaded() async {
    // Given
    mockService.mockInteractions = [createInteraction(id: "interaction1")]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertTrue(viewModel.canExport)
  }

  func testCanExport_FalseWhenNoInteraction() {
    XCTAssertFalse(viewModel.canExport)
  }

  // MARK: - Computed Properties Tests

  func testFormattedDate() async {
    // Given
    let interaction = createInteraction(id: "interaction1")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertFalse(viewModel.formattedDate.isEmpty)
    XCTAssertNotEqual(viewModel.formattedDate, "Unknown")
  }

  func testLoggedByDisplay_ShowsYouForCurrentUser() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertEqual(viewModel.loggedByDisplay, "You")
  }

  func testLoggedByDisplay_ShowsNameForOtherUser() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user2")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertEqual(viewModel.loggedByDisplay, "Test User")
  }

  func testDisplaySubject_ReturnsSubject() async {
    // Given
    let interaction = createInteraction(id: "interaction1", subject: "Test Subject")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertEqual(viewModel.displaySubject, "Test Subject")
  }

  func testDisplaySubject_ReturnsDefaultWhenNil() {
    XCTAssertEqual(viewModel.displaySubject, "Interaction")
  }

  func testHasContent_TrueWhenPresent() async {
    // Given
    let interaction = createInteraction(id: "interaction1", content: "Some content")
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertTrue(viewModel.hasContent)
  }

  func testHasContent_FalseWhenNil() async {
    // Given
    let interaction = createInteraction(id: "interaction1", content: nil)
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertFalse(viewModel.hasContent)
  }

  func testHasAttachments_TrueWhenPresent() async {
    // Given
    let interaction = createInteraction(id: "interaction1", attachments: ["url1"])
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertTrue(viewModel.hasAttachments)
  }

  func testHasAttachments_FalseWhenEmpty() async {
    // Given
    let interaction = createInteraction(id: "interaction1", attachments: [])
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()

    // Then
    XCTAssertFalse(viewModel.hasAttachments)
  }

  // MARK: - Export Tests

  func testExportInteraction_GeneratesCSV() async {
    // Given
    let interaction = createInteraction(
      id: "interaction1",
      subject: "Test Subject",
      content: "Test Content"
    )
    mockService.mockInteractions = [interaction]

    // When
    await viewModel.loadInteraction()
    let csv = viewModel.exportInteraction()

    // Then
    XCTAssertTrue(csv.contains("Field,Value"))
    XCTAssertTrue(csv.contains("Test Subject"))
    XCTAssertTrue(csv.contains("Test Content"))
    XCTAssertTrue(csv.contains("Email"))
    XCTAssertTrue(csv.contains("Outbound"))
  }

  func testExportInteraction_IncludesSchoolName() async {
    // Given
    let interaction = createInteraction(id: "interaction1", schoolId: "school1")
    let school = createSchool(id: "school1", name: "Stanford")
    mockService.mockInteractions = [interaction]
    mockService.mockSchools = [school]

    // When
    await viewModel.loadInteraction()
    let csv = viewModel.exportInteraction()

    // Then
    XCTAssertTrue(csv.contains("Stanford"))
  }

  func testExportInteraction_IncludesCoachName() async {
    // Given
    let interaction = createInteraction(id: "interaction1", coachId: "coach1")
    let coach = createCoach(id: "coach1", firstName: "John", lastName: "Smith")
    mockService.mockInteractions = [interaction]
    mockService.mockCoaches = [coach]

    // When
    await viewModel.loadInteraction()
    let csv = viewModel.exportInteraction()

    // Then
    XCTAssertTrue(csv.contains("John Smith"))
  }

  func testExportInteraction_ReturnsEmptyWhenNoInteraction() {
    // Given (no interaction loaded)

    // When
    let csv = viewModel.exportInteraction()

    // Then
    XCTAssertTrue(csv.isEmpty)
  }

  // MARK: - Delete Tests

  func testDeleteInteraction_Success() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]
    await viewModel.loadInteraction()

    // When
    let success = await viewModel.deleteInteraction()

    // Then
    XCTAssertTrue(success)
    XCTAssertEqual(mockService.deleteCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedId, "interaction1")
    XCTAssertFalse(viewModel.isDeleting)
  }

  func testDeleteInteraction_FailsWhenNoInteraction() async {
    // Given (no interaction loaded)

    // When
    let success = await viewModel.deleteInteraction()

    // Then
    XCTAssertFalse(success)
    XCTAssertEqual(mockService.deleteCallCount, 0)
  }

  func testDeleteInteraction_FailsWhenNotOwner() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user2")
    mockService.mockInteractions = [interaction]
    await viewModel.loadInteraction()

    // When
    let success = await viewModel.deleteInteraction()

    // Then
    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("permission") ?? false)
  }

  func testDeleteInteraction_CascadeFallback() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]
    await viewModel.loadInteraction()

    // Simulate FK constraint error on simple delete, cascade also fails
    mockService.simpleDeleteShouldFail = true
    mockService.shouldSucceed = false

    // When
    let success = await viewModel.deleteInteraction()

    // Then - both simple and cascade fail
    XCTAssertFalse(success)
    XCTAssertEqual(mockService.deleteCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCallCount, 1)
  }

  func testDeleteInteraction_CascadeSuccess() async {
    // Given
    let interaction = createInteraction(id: "interaction1", loggedBy: "user1")
    mockService.mockInteractions = [interaction]
    await viewModel.loadInteraction()

    // Simple delete fails with FK error, but cascade succeeds
    mockService.simpleDeleteShouldFail = true

    // When
    let success = await viewModel.deleteInteraction()

    // Then - cascade succeeds
    XCTAssertTrue(success)
    XCTAssertEqual(mockService.deleteCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCallCount, 1)
  }

  func testConfirmDelete_SetsShowDeleteConfirmation() {
    // When
    viewModel.confirmDelete()

    // Then
    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  func testCancelDelete_ClearsShowDeleteConfirmation() {
    // Given
    viewModel.showDeleteConfirmation = true

    // When
    viewModel.cancelDelete()

    // Then
    XCTAssertFalse(viewModel.showDeleteConfirmation)
  }

  // MARK: - Helper Methods

  private func createUser(id: String) -> User {
    User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )
  }

  private func createInteraction(
    id: String,
    schoolId: String? = "school1",
    coachId: String? = "coach1",
    subject: String? = "Subject",
    content: String? = "Content",
    attachments: [String]? = nil,
    loggedBy: String = "user1"
  ) -> Interaction {
    Interaction(
      id: id,
      type: .email,
      direction: .outbound,
      schoolId: schoolId,
      coachId: coachId,
      subject: subject,
      content: content,
      sentiment: .positive,
      occurredAt: ISO8601DateFormatter().string(from: Date()),
      loggedBy: loggedBy,
      attachments: attachments,
      familyUnitId: "family1",
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: nil
    )
  }

  private func createSchool(id: String, name: String = "Test School") -> School {
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
      priorityTier: nil,
      notes: nil,
      privateNotes: nil,
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
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "",
      updatedAt: ""
    )
  }

  private func createCoach(
    id: String,
    firstName: String = "John",
    lastName: String = "Smith"
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
      privateNotes: nil,
      responsivenessScore: 0.0,
      lastContactDate: nil,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date()
    )
    )
  }
}
