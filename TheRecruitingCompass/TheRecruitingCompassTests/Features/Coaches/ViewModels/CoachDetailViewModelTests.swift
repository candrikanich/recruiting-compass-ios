import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachDetailViewModelTests: XCTestCase {
  nonisolated deinit {}

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
      authManager: mockAuthManager,
      cache: InMemoryCache()
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
      statusChangedAt: nil, notes: nil,
      pros: [], cons: [], offerDetails: nil,
      academicInfo: nil, amenities: nil, coachingPhilosophy: nil, coachingStyle: nil,
      recruitingApproach: nil, communicationStyle: nil, successMetrics: nil, familyUnitId: "family-1", createdBy: nil, updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  private func makeInteraction(
    id: String,
    type: InteractionType = .email,
    occurredAt: String? = "2026-02-08T10:00:00Z"
  ) -> Interaction {
    Interaction(
      id: id, type: type, direction: .outbound, schoolId: "school-1", coachId: "coach-1",
      subject: "Test", content: nil, sentiment: .positive, occurredAt: occurredAt,
      loggedBy: "user-1", attachments: nil, familyUnitId: "family-1",
      createdAt: "2026-02-08T10:00:00Z", updatedAt: nil
    )
  }

  /// ISO-8601 string N days before now — for date-relative days-since assertions.
  private func iso8601(daysAgo: Int) -> String {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    return ISO8601DateFormatter().string(from: date)
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
      authManager: mockAuthManager,
      cache: InMemoryCache()
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
    // Pulls the full history (not just the last handful) so metrics are accurate.
    XCTAssertEqual(mockService.lastFetchInteractionsLimit, 500)
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

  /// Days-since derives from the newest logged interaction, not the stored
  /// `last_contact_date`, so it is correct in-session without a refetch.
  func testComputeStats_DaysSince_DerivesFromNewestInteraction() async {
    // Stored date is stale (30 days ago); newest interaction is yesterday.
    testCoach = makeCoach(id: "coach-1", lastContactDate: iso8601(daysAgo: 30))
    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager,
      cache: InMemoryCache()
    )

    await sut.loadCoach()
    mockService.stubbedInteractions = [
      makeInteraction(id: "1", occurredAt: iso8601(daysAgo: 5)),
      makeInteraction(id: "2", occurredAt: iso8601(daysAgo: 1))
    ]
    await sut.loadDetails()

    XCTAssertEqual(sut.stats?.daysSinceContact, 1)
    XCTAssertEqual(sut.stats?.contactStatusText, "1 days ago")
  }

  /// With no interactions, days-since falls back to the stored `last_contact_date`.
  func testComputeStats_DaysSince_FallsBackToStoredDate() async {
    testCoach = makeCoach(id: "coach-1", lastContactDate: iso8601(daysAgo: 1))
    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager,
      cache: InMemoryCache()
    )

    await sut.loadCoach()
    mockService.stubbedInteractions = []
    await sut.loadDetails()

    XCTAssertEqual(sut.stats?.daysSinceContact, 1)
  }

  /// A nil-`occurredAt` interaction must not masquerade as "today" (its
  /// `displayDate` defaults to `.now`); days-since falls back to the stored date.
  func testComputeStats_DaysSince_IgnoresNilOccurredAt() async {
    testCoach = makeCoach(id: "coach-1", lastContactDate: iso8601(daysAgo: 7))
    sut = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager,
      cache: InMemoryCache()
    )

    await sut.loadCoach()
    mockService.stubbedInteractions = [makeInteraction(id: "1", occurredAt: nil)]
    await sut.loadDetails()

    XCTAssertEqual(sut.stats?.daysSinceContact, 7)
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
    sut.editedSharedNotes = "New shared notes"

    let updatedCoach = makeCoach(id: "coach-1", notes: "New shared notes")
    mockService.stubbedUpdatedCoach = updatedCoach

    await sut.saveSharedNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(sut.coach?.notes, "New shared notes")
    XCTAssertEqual(sut.saveStatus, .saved)
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
    sut.editedSharedNotes = "New notes"

    mockService.shouldThrowUpdateCoach = true

    await sut.saveSharedNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to save notes")
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
    let coachNoContact = makeCoach(id: "coach-1", lastContactDate: nil)
    // Set coach directly to avoid cache contamination from other tests
    sut.coach = coachNoContact
    // Neither a stored date nor any dated interaction → days-since is nil.
    mockService.stubbedInteractions = []
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

}
