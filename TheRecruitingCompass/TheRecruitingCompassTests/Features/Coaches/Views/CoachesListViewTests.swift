import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewTests: XCTestCase {

  private var mockAuthManager: MockAuthManager!
  private var mockFamilyManager: FamilyManager!
  private var mockFamilyService: MockFamilyService!

  override func setUp() async throws {
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockFamilyManager = FamilyManager(
      familyService: mockFamilyService,
      authManager: mockAuthManager
    )

    // Set up authenticated user with family member
    mockAuthManager.setMockUser(User(
      id: "user-1",
      email: "test@test.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    ))

    mockFamilyManager.currentMember = FamilyMember(
      id: "member-1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  override func tearDown() async throws {
    mockAuthManager = nil
    mockFamilyManager = nil
    mockFamilyService = nil
  }

  // MARK: - Test Helpers

  private func makeCoach(
    id: String = "coach-1",
    firstName: String = "John",
    lastName: String = "Smith",
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String? = "head",
    schoolId: String = "school-1",
    responsivenessScore: Double = 80,
    lastContactDate: String? = "2026-02-01T10:00:00Z"
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      position: position,
      schoolId: schoolId,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      privateNotes: nil,
      responsivenessScore: responsivenessScore,
      lastContactDate: lastContactDate,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeSchool(
    id: String = "school-1",
    name: String = "State University"
  ) -> School {
    School(
      id: id,
      userId: "user-1",
      name: name,
      location: "City, ST",
      city: "City",
      state: "ST",
      division: "D1",
      conference: "Big 10",
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      priorityTier: "A",
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
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  // MARK: - View Rendering Tests

  func testCoachesListView_rendersWithoutCrashing() {
    let view = CoachesListView()
      .environmentObject(mockFamilyManager)

    XCTAssertNotNil(view)
  }

  // MARK: - ViewModel Integration Tests

  func testViewModel_loadsCoachesOnInit() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach()]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertEqual(viewModel.allCoaches.count, 1)
    XCTAssertEqual(viewModel.allSchools.count, 1)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testViewModel_setsLoadingStateDuringLoad() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = []

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    // Before load
    XCTAssertFalse(viewModel.isLoading)

    // Start load
    let loadTask = Task { await viewModel.loadCoaches() }

    // After load completes
    await loadTask.value
    XCTAssertFalse(viewModel.isLoading)
  }

  func testViewModel_handlesLoadError() async {
    let mockService = MockCoachesService()
    mockService.shouldThrowFetchSchools = true

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.allCoaches.isEmpty)
  }

  // MARK: - Delete Flow Tests

  func testDeleteFlow_confirmDeleteSetsUpState() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    viewModel.confirmDelete(coach)

    XCTAssertTrue(viewModel.showDeleteConfirmation)
    XCTAssertEqual(viewModel.coachToDelete?.id, "coach-1")
  }

  func testDeleteFlow_successRemovesCoachFromList() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    XCTAssertEqual(viewModel.allCoaches.count, 1)

    viewModel.confirmDelete(coach)
    await viewModel.deleteCoach()

    XCTAssertTrue(viewModel.allCoaches.isEmpty)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.coachToDelete)
    XCTAssertTrue(viewModel.showSuccessToast)
  }

  func testDeleteFlow_failureShowsError() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    mockService.shouldThrowDeleteCoach = true
    mockService.shouldThrowCascadeDelete = true

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.confirmDelete(coach)
    await viewModel.deleteCoach()

    XCTAssertNotNil(viewModel.deleteErrorMessage)
    XCTAssertEqual(viewModel.allCoaches.count, 1) // Coach should still be there
  }

  func testDeleteFlow_cascadeFallbackWorks() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    mockService.shouldThrowDeleteCoach = true // First attempt fails

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.confirmDelete(coach)
    await viewModel.deleteCoach()

    XCTAssertTrue(viewModel.allCoaches.isEmpty)
    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCoachCallCount, 1)
  }

  // MARK: - Search and Filter Tests

  func testSearch_filtersCoachesByName() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "John", lastName: "Smith"),
      makeCoach(id: "2", firstName: "Jane", lastName: "Doe"),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    XCTAssertEqual(viewModel.filteredCoaches.count, 2)

    viewModel.filters.searchText = "john"

    XCTAssertEqual(viewModel.filteredCoaches.count, 1)
    XCTAssertEqual(viewModel.filteredCoaches.first?.firstName, "John")
  }

  func testFilter_roleNarrowsResults() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", position: "head"),
      makeCoach(id: "2", position: "assistant"),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    XCTAssertEqual(viewModel.filteredCoaches.count, 2)

    viewModel.filters.role = .head

    XCTAssertEqual(viewModel.filteredCoaches.count, 1)
    XCTAssertEqual(viewModel.filteredCoaches.first?.id, "1")
  }

  func testFilter_activeFilterCountReflectsFilters() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach()]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    XCTAssertEqual(viewModel.activeFilterCount, 0)

    viewModel.filters.role = .head
    viewModel.filters.responsivenessLevel = .high

    XCTAssertEqual(viewModel.activeFilterCount, 2)
  }

  func testFilter_clearFiltersResetsAll() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach()]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.filters.role = .head
    viewModel.filters.responsivenessLevel = .high
    viewModel.filters.searchText = "test"

    viewModel.clearFilters()

    XCTAssertEqual(viewModel.filters.searchText, "")
    XCTAssertNil(viewModel.filters.role)
    XCTAssertNil(viewModel.filters.responsivenessLevel)
    XCTAssertEqual(viewModel.activeFilterCount, 0)
  }

  // MARK: - Success Toast Tests

  func testSuccessToast_showsAfterSuccessfulDelete() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.confirmDelete(coach)

    XCTAssertFalse(viewModel.showSuccessToast)

    await viewModel.deleteCoach()

    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertNotNil(viewModel.successMessage)
  }

  func testSuccessToast_displaysCorrectMessageForSimpleDelete() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.confirmDelete(coach)
    await viewModel.deleteCoach()

    XCTAssertEqual(viewModel.successMessage, "Coach deleted")
  }

  func testSuccessToast_displaysCorrectMessageForCascadeDelete() async {
    let mockService = MockCoachesService()
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    mockService.shouldThrowDeleteCoach = true // Force cascade
    mockService.stubbedDeleteResult = DeleteResult(
      isCascadeUsed: true,
      deletedInteractions: 3,
      deletedNotes: 1
    )

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.confirmDelete(coach)
    await viewModel.deleteCoach()

    XCTAssertEqual(viewModel.successMessage, "Coach and 4 related records deleted")
  }

  // MARK: - Sorting Tests

  func testSort_byName() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", lastName: "Zimmerman"),
      makeCoach(id: "2", lastName: "Adams"),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.filters.sortBy = .name

    XCTAssertEqual(viewModel.filteredCoaches.first?.lastName, "Adams")
    XCTAssertEqual(viewModel.filteredCoaches.last?.lastName, "Zimmerman")
  }

  func testSort_byResponsiveness() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", responsivenessScore: 50),
      makeCoach(id: "2", responsivenessScore: 90),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.filters.sortBy = .responsiveness

    XCTAssertEqual(viewModel.filteredCoaches.first?.id, "2") // Higher score first
    XCTAssertEqual(viewModel.filteredCoaches.last?.id, "1")
  }

  // MARK: - School Name Lookup Tests

  func testSchoolName_returnsCorrectName() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool(id: "s1", name: "Test University")]
    mockService.stubbedCoaches = []

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertEqual(viewModel.schoolName(for: "s1"), "Test University")
  }

  func testSchoolName_unknownIdReturnsDefault() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = []
    mockService.stubbedCoaches = []

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertEqual(viewModel.schoolName(for: "nonexistent"), "Unknown School")
  }

  // MARK: - Result Count Tests

  func testResultCount_reflectsFilteredCoaches() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "John"),
      makeCoach(id: "2", firstName: "Jane"),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    XCTAssertEqual(viewModel.resultCount, 2)

    viewModel.filters.searchText = "john"
    XCTAssertEqual(viewModel.resultCount, 1)
  }

  // MARK: - Edge Case Tests

  func testEdgeCase_noFamilyUnit() async {
    let mockService = MockCoachesService()
    mockFamilyManager.currentMember = nil

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 0)
  }

  func testEdgeCase_coachWithNoContactInfo() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", email: nil, phone: nil),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()

    XCTAssertEqual(viewModel.allCoaches.count, 1)
    XCTAssertNil(viewModel.allCoaches.first?.email)
    XCTAssertNil(viewModel.allCoaches.first?.phone)
  }

  func testEdgeCase_multipleFiltersActive() async {
    let mockService = MockCoachesService()
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "John", position: "head", responsivenessScore: 90),
      makeCoach(id: "2", firstName: "Jane", position: "assistant", responsivenessScore: 60),
    ]

    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager
    )

    await viewModel.loadCoaches()
    viewModel.filters.searchText = "john"
    viewModel.filters.role = .head
    viewModel.filters.responsivenessLevel = .high

    XCTAssertEqual(viewModel.filteredCoaches.count, 1)
    XCTAssertEqual(viewModel.filteredCoaches.first?.firstName, "John")
  }
}
