import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachDetailViewModelTests: XCTestCase {

  private var sut: CoachDetailViewModel!
  private var mockService: MockCoachesService!
  private var mockAuthManager: MockAuthManager!
  private var testCoach: Coach!
  private var testSchool: School!

  override func setUp() async throws {
    mockService = MockCoachesService()
    mockAuthManager = MockAuthManager()

    mockAuthManager.setMockUser(User(
      id: "user-1",
      email: "test@test.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    ))

    testCoach = makeCoach(id: "coach-1", firstName: "John", lastName: "Smith")
    testSchool = makeSchool(id: "school-1", name: "State University")

    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() async throws {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    testCoach = nil
    testSchool = nil
  }

  // MARK: - Test Helpers

  private func makeCoach(
    id: String,
    firstName: String = "John",
    lastName: String = "Smith",
    notes: String? = nil,
    privateNotes: [String: String]? = nil,
    lastContactDate: String? = "2026-02-01T10:00:00Z"
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: "john@school.edu",
      phone: "555-1234",
      position: "head",
      schoolId: "school-1",
      twitterHandle: "@coach",
      instagramHandle: "@coach",
      notes: notes,
      privateNotes: privateNotes,
      responsivenessScore: 80,
      lastContactDate: lastContactDate,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeSchool(id: String, name: String) -> School {
    School(
      id: id, userId: "user-1", name: name, location: "City, ST", city: "City", state: "ST",
      division: "D1", conference: "Big Ten", ranking: nil, isFavorite: false, website: nil,
      faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil, status: "interested",
      statusChangedAt: nil, priorityTier: "A", notes: nil,
          privateNotes: nil, pros: [], cons: [], offerDetails: nil,
      academicInfo: nil, amenities: nil, coachingPhilosophy: nil, coachingStyle: nil,
      recruitingApproach: nil, communicationStyle: nil, successMetrics: nil, fitScore: nil,
      fitTier: nil, familyUnitId: "family-1", createdBy: nil, updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  private func makeInteraction(id: String, type: InteractionType = .email) -> Interaction {
    Interaction(
      id: id, type: type, direction: .outbound, schoolId: "school-1", coachId: "coach-1",
      subject: "Test", content: nil, sentiment: .positive, occurredAt: "2026-02-08T10:00:00Z",
      loggedBy: "user-1", attachments: nil, familyUnitId: "family-1",
      createdAt: "2026-02-08T10:00:00Z", updatedAt: nil
    )
  }

  // MARK: - Loading Tests

  func testLoadCoach_Success() async {
    await sut.loadCoach()

    XCTAssertNotNil(sut.coach)
    XCTAssertEqual(sut.coach?.id, "coach-1")
    XCTAssertEqual(sut.school?.name, "State University")
    XCTAssertNil(sut.errorMessage)
  }

  func testLoadCoach_NotFound() async {
    sut = CoachDetailViewModel(
      coachId: "nonexistent",
      allCoaches: [],
      allSchools: [],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await sut.loadCoach()

    XCTAssertNil(sut.coach)
    XCTAssertEqual(sut.errorMessage, "Coach not found")
  }

  func testLoadDetails_Success() async {
    await sut.loadCoach()

    mockService.stubbedInteractions = [
      makeInteraction(id: "1", type: .email),
      makeInteraction(id: "2", type: .phoneCall)
    ]

    await sut.loadDetails()

    XCTAssertEqual(sut.recentInteractions.count, 2)
    XCTAssertNotNil(sut.stats)
    XCTAssertEqual(sut.stats?.totalInteractions, 2)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchInteractionsCoachId, "coach-1")
    XCTAssertEqual(mockService.lastFetchInteractionsLimit, 10)
  }

  func testLoadDetails_Failure() async {
    await sut.loadCoach()

    mockService.shouldThrowFetchInteractions = true

    await sut.loadDetails()

    XCTAssertEqual(sut.recentInteractions.count, 0)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Stats Tests

  func testComputeStats_WithInteractions() async {
    await sut.loadCoach()

    mockService.stubbedInteractions = [
      makeInteraction(id: "1", type: .email),
      makeInteraction(id: "2", type: .email),
      makeInteraction(id: "3", type: .phoneCall)
    ]

    await sut.loadDetails()

    XCTAssertEqual(sut.stats?.totalInteractions, 3)
    XCTAssertEqual(sut.stats?.preferredMethod, "Email")
  }

  func testComputeStats_DaysSinceContact() async {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let dateString = ISO8601DateFormatter().string(from: yesterday)

    testCoach = makeCoach(id: "coach-1", lastContactDate: dateString)
    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await sut.loadCoach()
    mockService.stubbedInteractions = [makeInteraction(id: "1")]
    await sut.loadDetails()

    XCTAssertEqual(sut.stats?.daysSinceContact, 1)
    XCTAssertEqual(sut.stats?.contactStatusText, "1 days ago")
  }

  // MARK: - Edit Tests

  func testStartEditing() {
    sut.coach = testCoach
    sut.startEditing()

    XCTAssertTrue(sut.isEditing)
    XCTAssertNotNil(sut.editedCoach)
    XCTAssertEqual(sut.editedCoach?.firstName, "John")
    XCTAssertTrue(sut.validationErrors.isEmpty)
  }

  func testCancelEditing() {
    sut.coach = testCoach
    sut.startEditing()
    sut.cancelEditing()

    XCTAssertFalse(sut.isEditing)
    XCTAssertNil(sut.editedCoach)
    XCTAssertTrue(sut.validationErrors.isEmpty)
  }

  func testSaveChanges_Success() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.firstName = "Jane"

    let updatedCoach = makeCoach(id: "coach-1", firstName: "Jane")
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.saveChanges()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(sut.coach?.firstName, "Jane")
    XCTAssertFalse(sut.isEditing)
    XCTAssertNil(sut.editedCoach)
  }

  func testSaveChanges_ValidationFailure() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.firstName = ""

    await sut.saveChanges()

    XCTAssertEqual(mockService.updateCoachCallCount, 0)
    XCTAssertFalse(sut.validationErrors.isEmpty)
    XCTAssertNotNil(sut.validationErrors["firstName"])
    XCTAssertTrue(sut.isEditing)
  }

  // MARK: - Validation Tests

  func testValidateEdits_AllValid() {
    sut.coach = testCoach
    sut.startEditing()

    XCTAssertTrue(sut.validationErrors.isEmpty)
  }

  func testValidateEdits_InvalidEmail() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.email = "invalid-email"

    await sut.saveChanges()

    XCTAssertNotNil(sut.validationErrors["email"])
  }

  func testValidateEdits_TwitterTooLong() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.twitterHandle = "@verylonghandleover15chars"

    await sut.saveChanges()

    XCTAssertNotNil(sut.validationErrors["twitterHandle"])
  }

  func testValidateEdits_InstagramTooLong() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.instagramHandle = String(repeating: "a", count: 31)

    await sut.saveChanges()

    XCTAssertNotNil(sut.validationErrors["instagramHandle"])
  }

  // MARK: - Shared Notes Tests

  func testSaveSharedNotes_Success() async {
    sut.coach = testCoach
    sut.startEditingSharedNotes()
    sut.editedSharedNotes = "New shared notes"

    let updatedCoach = makeCoach(id: "coach-1", notes: "New shared notes")
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.saveSharedNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(sut.coach?.notes, "New shared notes")
    XCTAssertFalse(sut.isEditingSharedNotes)
  }

  // MARK: - Private Notes Tests

  func testSavePrivateNotes_MergesExisting() async {
    let existingPrivateNotes = ["user-2": "User 2's note"]
    testCoach = makeCoach(id: "coach-1", privateNotes: existingPrivateNotes)
    sut.coach = testCoach

    sut.startEditingPrivateNotes()
    sut.editedPrivateNotes = "My private note"

    let updatedCoach = makeCoach(
      id: "coach-1",
      privateNotes: ["user-1": "My private note", "user-2": "User 2's note"]
    )
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.savePrivateNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    let lastUpdate = mockService.lastUpdateCoachUpdates
    XCTAssertEqual(lastUpdate?.privateNotes?.count, 2)
    XCTAssertEqual(lastUpdate?.privateNotes?["user-1"], "My private note")
    XCTAssertEqual(lastUpdate?.privateNotes?["user-2"], "User 2's note")
  }

  func testPrivateNoteForCurrentUser() {
    testCoach = makeCoach(
      id: "coach-1",
      privateNotes: ["user-1": "My note", "user-2": "Other note"]
    )
    sut.coach = testCoach

    XCTAssertEqual(sut.privateNoteForCurrentUser, "My note")
  }

  // MARK: - Delete Tests

  func testDeleteCoach_Simple() async {
    sut.coach = testCoach

    await sut.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedCoachId, "coach-1")
    XCTAssertNotNil(sut.deleteSuccessMessage)
    XCTAssertEqual(sut.deleteSuccessMessage, "Coach deleted")
  }

  func testDeleteCoach_CascadeFallback() async {
    sut.coach = testCoach

    mockService.shouldThrowDeleteCoach = true

    await sut.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCoachCallCount, 1)
    XCTAssertNotNil(sut.deleteSuccessMessage)
    XCTAssertTrue(sut.deleteSuccessMessage?.contains("interactions") == true)
  }

  func testDeleteCoach_Failure() async {
    sut.coach = testCoach

    mockService.shouldThrowDeleteCoach = true
    mockService.shouldThrowCascadeDelete = true

    await sut.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCoachCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Error Handling Tests

  func testSaveChanges_ServiceError_SetsErrorMessage() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.firstName = "Jane"

    mockService.shouldThrowUpdateCoach = true

    await sut.saveChanges()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to save changes")
  }

  func testSaveSharedNotes_ServiceError_SetsErrorMessage() async {
    sut.coach = testCoach
    sut.startEditingSharedNotes()
    sut.editedSharedNotes = "New notes"

    mockService.shouldThrowUpdateCoach = true

    await sut.saveSharedNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to save notes")
  }

  func testSavePrivateNotes_ServiceError_SetsErrorMessage() async {
    sut.coach = testCoach
    sut.startEditingPrivateNotes()
    sut.editedPrivateNotes = "Private note"

    mockService.shouldThrowUpdateCoach = true

    await sut.savePrivateNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to save private notes")
  }

  // MARK: - Edge Case Tests

  func testLoadDetails_EmptyInteractions_SetsEmptyArray() async {
    await sut.loadCoach()

    mockService.stubbedInteractions = []

    await sut.loadDetails()

    XCTAssertEqual(sut.recentInteractions.count, 0)
    XCTAssertNotNil(sut.stats)
    XCTAssertEqual(sut.stats?.totalInteractions, 0)
  }

  func testComputeStats_NoLastContact_DaysSinceContactNil() async {
    testCoach = makeCoach(id: "coach-1", lastContactDate: nil)
    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await sut.loadCoach()
    mockService.stubbedInteractions = [makeInteraction(id: "1")]
    await sut.loadDetails()

    XCTAssertNil(sut.stats?.daysSinceContact)
    XCTAssertEqual(sut.stats?.contactStatusText, "Never")
  }

  func testComputeStats_NoInteractions_PreferredMethodNil() async {
    await sut.loadCoach()

    mockService.stubbedInteractions = []

    await sut.loadDetails()

    XCTAssertNil(sut.stats?.preferredMethod)
  }

  func testValidateEdits_NotesExactly5000Chars_Valid() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.notes = String(repeating: "a", count: 5000)

    let updatedCoach = makeCoach(id: "coach-1", notes: String(repeating: "a", count: 5000))
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.saveChanges()

    XCTAssertTrue(sut.validationErrors.isEmpty)
    XCTAssertEqual(mockService.updateCoachCallCount, 1)
  }

  func testValidateEdits_NotesOver5000Chars_Invalid() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.notes = String(repeating: "a", count: 5001)

    await sut.saveChanges()

    XCTAssertFalse(sut.validationErrors.isEmpty)
    XCTAssertNotNil(sut.validationErrors["notes"])
    XCTAssertEqual(mockService.updateCoachCallCount, 0)
  }

  func testValidateEdits_EmptyEmail_Valid() async {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.email = ""

    let updatedCoach = makeCoach(id: "coach-1")
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.saveChanges()

    XCTAssertTrue(sut.validationErrors.isEmpty)
    XCTAssertEqual(mockService.updateCoachCallCount, 1)
  }

  func testEditableCoachBinding_CoachNil_ReturnsEmpty() {
    sut.coach = nil
    sut.editedCoach = nil

    let binding = sut.editableCoachBinding
    let value = binding.wrappedValue

    XCTAssertEqual(value.firstName, "")
    XCTAssertEqual(value.lastName, "")
  }

  func testEditableCoachBinding_UsesEditedCoachWhenPresent() {
    sut.coach = testCoach
    sut.startEditing()
    sut.editedCoach?.firstName = "Modified"

    let binding = sut.editableCoachBinding
    let value = binding.wrappedValue

    XCTAssertEqual(value.firstName, "Modified")
  }

  func testCancelEditingSharedNotes_ResetsState() {
    sut.coach = makeCoach(id: "coach-1", notes: "Original notes")
    sut.startEditingSharedNotes()
    sut.editedSharedNotes = "Modified notes"

    sut.cancelEditingSharedNotes()

    XCTAssertFalse(sut.isEditingSharedNotes)
    XCTAssertEqual(sut.editedSharedNotes, "")
  }

  func testCancelEditingPrivateNotes_ResetsState() {
    testCoach = makeCoach(id: "coach-1", privateNotes: ["user-1": "Original note"])
    sut.coach = testCoach
    sut.startEditingPrivateNotes()
    sut.editedPrivateNotes = "Modified note"

    sut.cancelEditingPrivateNotes()

    XCTAssertFalse(sut.isEditingPrivateNotes)
    XCTAssertEqual(sut.editedPrivateNotes, "")
  }
}
