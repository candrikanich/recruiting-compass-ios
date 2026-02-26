import XCTest
import SwiftUI
import UIKit
@testable import TheRecruitingCompass

@MainActor
final class CoachDetailViewTests: XCTestCase {

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
  }

  override func tearDown() async throws {
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

  // MARK: - View Rendering Tests

  func testCoachDetailView_rendersWithoutCrashing() {
    // Host in UIHostingController so @MainActor CoachDetailViewModel tears down in a proper
    // UIKit context. Use AnyView so we can replace rootView before test end and release the
    // ViewModel on Main, avoiding the Swift runtime deinit crash (malloc "pointer being
    // freed was not allocated" in swift_task_deinitOnExecutorMainActorBackDeploy).
    let view = CoachDetailView(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool]
    )
    let hosting = UIHostingController(rootView: AnyView(view))
    XCTAssertNotNil(hosting.view)
    hosting.rootView = AnyView(EmptyView())
    RunLoop.main.run(until: Date())
  }

  func testCoachDetailView_rendersWithEmptyCoaches() {
    let view = CoachDetailView(
      coachId: "coach-1",
      allCoaches: [],
      allSchools: []
    )
    let hosting = UIHostingController(rootView: AnyView(view))
    XCTAssertNotNil(hosting.view)
    hosting.rootView = AnyView(EmptyView())
    RunLoop.main.run(until: Date())
  }

  // MARK: - ViewModel Integration Tests

  func testViewModel_loadsCoachSuccessfully() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await viewModel.loadCoach()

    XCTAssertNotNil(viewModel.coach)
    XCTAssertEqual(viewModel.coach?.id, "coach-1")
    XCTAssertEqual(viewModel.school?.name, "State University")
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testViewModel_handlesCoachNotFound() async {
    let viewModel = CoachDetailViewModel(
      coachId: "nonexistent",
      allCoaches: [],
      allSchools: [],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await viewModel.loadCoach()

    XCTAssertNil(viewModel.coach)
    XCTAssertEqual(viewModel.errorMessage, "Coach not found")
    XCTAssertFalse(viewModel.isLoading)
  }

  func testViewModel_loadsDetailsSuccessfully() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await viewModel.loadCoach()

    mockService.stubbedInteractions = [
      makeInteraction(id: "1", type: .email),
      makeInteraction(id: "2", type: .phoneCall)
    ]

    await viewModel.loadDetails()

    XCTAssertEqual(viewModel.recentInteractions.count, 2)
    XCTAssertNotNil(viewModel.stats)
    XCTAssertEqual(viewModel.stats?.totalInteractions, 2)
  }

  func testViewModel_handlesLoadDetailsError() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    await viewModel.loadCoach()

    mockService.shouldThrowFetchInteractions = true

    await viewModel.loadDetails()

    XCTAssertEqual(viewModel.recentInteractions.count, 0)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  // MARK: - Edit Flow Tests

  func testEditFlow_startEditingSetsState() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditing()

    XCTAssertTrue(viewModel.isEditing)
    XCTAssertNotNil(viewModel.editedCoach)
    XCTAssertEqual(viewModel.editedCoach?.firstName, "John")
    XCTAssertTrue(viewModel.validationErrors.isEmpty)
  }

  func testEditFlow_cancelEditingResetsState() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditing()
    viewModel.cancelEditing()

    XCTAssertFalse(viewModel.isEditing)
    XCTAssertNil(viewModel.editedCoach)
    XCTAssertTrue(viewModel.validationErrors.isEmpty)
  }

  func testEditFlow_saveChangesSuccessfully() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditing()
    viewModel.editedCoach?.firstName = "Jane"

    let updatedCoach = makeCoach(id: "coach-1", firstName: "Jane")
    mockService.stubbedUpdatedCoach = updatedCoach

    await viewModel.saveChanges()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(viewModel.coach?.firstName, "Jane")
    XCTAssertFalse(viewModel.isEditing)
    XCTAssertNil(viewModel.editedCoach)
  }

  func testEditFlow_validationPreventsInvalidSave() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditing()
    viewModel.editedCoach?.firstName = "" // Invalid

    await viewModel.saveChanges()

    XCTAssertEqual(mockService.updateCoachCallCount, 0)
    XCTAssertFalse(viewModel.validationErrors.isEmpty)
    XCTAssertNotNil(viewModel.validationErrors["firstName"])
    XCTAssertTrue(viewModel.isEditing)
  }

  // MARK: - Delete Flow Tests

  func testDeleteFlow_confirmDeleteShowsDialog() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.confirmDelete()

    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  func testDeleteFlow_deleteCoachSuccessfully() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach

    await viewModel.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedCoachId, "coach-1")
    XCTAssertNotNil(viewModel.deleteSuccessMessage)
    XCTAssertEqual(viewModel.deleteSuccessMessage, "Coach deleted")
  }

  func testDeleteFlow_cascadeDeleteOnForeignKeyError() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach

    mockService.shouldThrowDeleteCoach = true

    await viewModel.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCoachCallCount, 1)
    XCTAssertNotNil(viewModel.deleteSuccessMessage)
    XCTAssertTrue(viewModel.deleteSuccessMessage?.contains("interactions") == true)
  }

  // MARK: - Notes Flow Tests

  func testNotesFlow_sharedNotesEditAndSave() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditingSharedNotes()

    XCTAssertTrue(viewModel.isEditingSharedNotes)
    XCTAssertEqual(viewModel.editedSharedNotes, "")

    viewModel.editedSharedNotes = "New shared notes"

    let updatedCoach = makeCoach(id: "coach-1", notes: "New shared notes")
    mockService.stubbedUpdatedCoach = updatedCoach

    await viewModel.saveSharedNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(viewModel.coach?.notes, "New shared notes")
    XCTAssertFalse(viewModel.isEditingSharedNotes)
  }

  func testNotesFlow_privateNotesEditAndSave() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditingPrivateNotes()

    XCTAssertTrue(viewModel.isEditingPrivateNotes)
    XCTAssertEqual(viewModel.editedPrivateNotes, "")

    viewModel.editedPrivateNotes = "My private note"

    let updatedCoach = makeCoach(
      id: "coach-1",
      privateNotes: ["user-1": "My private note"]
    )
    mockService.stubbedUpdatedCoach = updatedCoach

    await viewModel.savePrivateNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    XCTAssertEqual(viewModel.privateNoteForCurrentUser, "My private note")
    XCTAssertFalse(viewModel.isEditingPrivateNotes)
  }

  func testNotesFlow_privateNotesMergesExistingUserNotes() async {
    let existingPrivateNotes = ["user-2": "User 2's note"]
    let coachWithNotes = makeCoach(id: "coach-1", privateNotes: existingPrivateNotes)

    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [coachWithNotes],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = coachWithNotes
    viewModel.startEditingPrivateNotes()
    viewModel.editedPrivateNotes = "My private note"

    let updatedCoach = makeCoach(
      id: "coach-1",
      privateNotes: ["user-1": "My private note", "user-2": "User 2's note"]
    )
    mockService.stubbedUpdatedCoach = updatedCoach

    await viewModel.savePrivateNotes()

    XCTAssertEqual(mockService.updateCoachCallCount, 1)
    let lastUpdate = mockService.lastUpdateCoachUpdates
    XCTAssertEqual(lastUpdate?.privateNotes?.count, 2)
    XCTAssertEqual(lastUpdate?.privateNotes?["user-1"], "My private note")
    XCTAssertEqual(lastUpdate?.privateNotes?["user-2"], "User 2's note")
  }

  // MARK: - Loading State Tests

  func testLoadingState_setsDuringLoadCoach() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    XCTAssertFalse(viewModel.isLoading)

    let loadTask = Task { await viewModel.loadCoach() }
    await loadTask.value

    XCTAssertFalse(viewModel.isLoading)
  }

  func testSavingState_setsDuringSaveChanges() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach
    viewModel.startEditing()
    viewModel.editedCoach?.firstName = "Jane"

    let updatedCoach = makeCoach(id: "coach-1", firstName: "Jane")
    mockService.stubbedUpdatedCoach = updatedCoach

    XCTAssertFalse(viewModel.isSaving)

    let saveTask = Task { await viewModel.saveChanges() }
    await saveTask.value

    XCTAssertFalse(viewModel.isSaving)
  }

  func testDeletingState_setsDuringDelete() async {
    let viewModel = CoachDetailViewModel(
      coachId: "coach-1",
      allCoaches: [testCoach],
      allSchools: [testSchool],
      coachesService: mockService,
      authManager: mockAuthManager
    )

    viewModel.coach = testCoach

    XCTAssertFalse(viewModel.isDeleting)

    let deleteTask = Task { await viewModel.deleteCoach() }
    await deleteTask.value

    XCTAssertFalse(viewModel.isDeleting)
  }
}
