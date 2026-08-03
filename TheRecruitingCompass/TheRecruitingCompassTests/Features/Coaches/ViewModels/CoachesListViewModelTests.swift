import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: CoachesListViewModel!
  private var mockService: MockCoachesService!
  private var mockAuthManager: MockAuthManager!
  private var mockFamilyManager: FamilyManager!
  private var mockFamilyService: MockFamilyService!
  private var mockCache: InMemoryCache!

  override func setUp() async throws {
    mockService = MockCoachesService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    // Fresh instance per test — InMemoryCache.shared would leak state across tests.
    mockCache = InMemoryCache()
    mockFamilyManager = FamilyManager(
      familyService: mockFamilyService,
      authManager: mockAuthManager
    )

    mockAuthManager.setMockUser(User(
      id: "user-1",
      email: "test@test.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    ))

    mockFamilyManager.currentMember = FamilyMember(
      id: "member-1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )

    sut = CoachesListViewModel(
      coachesService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager,
      cache: mockCache
    )
  }

  override func tearDown() async throws {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    mockFamilyManager = nil
    mockFamilyService = nil
    mockCache = nil
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
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil,
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
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      notes: notes,
      lastContactDate: lastContactDate,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeSchool(id: String = "school-1", name: String = "State University") -> School {
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
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  // MARK: - Loading Tests

  func testLoadCoaches_fetchesSchoolsThenCoaches() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach()]

    await sut.loadCoaches()

    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchSchoolsFamilyUnitId, "family-1")
    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)
    XCTAssertEqual(sut.allCoaches.count, 1)
    XCTAssertEqual(sut.allSchools.count, 1)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadCoaches_setsLoadingState() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = []

    await sut.loadCoaches()

    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
  }

  func testLoadCoaches_networkError_setsErrorMessage() async {
    mockService.shouldThrowFetchSchools = true

    await sut.loadCoaches()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.allCoaches.isEmpty)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadCoaches_noFamilyUnit_setsErrorMessage() async {
    mockFamilyManager.currentMember = nil

    await sut.loadCoaches()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 0)
  }

  // MARK: - Search Filter Tests

  func testSearchFilter_matchesName() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "John", lastName: "Smith", email: "coach1@school.edu"),
      makeCoach(id: "2", firstName: "Jane", lastName: "Doe", email: "coach2@school.edu"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "john"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.firstName, "John")
  }

  func testSearchFilter_matchesEmail() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", email: "john@school.edu"),
      makeCoach(id: "2", email: "jane@university.edu"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "university"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
  }

  func testSearchFilter_matchesPhone() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", phone: "555-1234"),
      makeCoach(id: "2", phone: "555-9999"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "9999"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
  }

  func testSearchFilter_matchesNotes() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", notes: "Great recruiter"),
      makeCoach(id: "2", notes: "Average"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "recruiter"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
  }

  func testSearchFilter_matchesTwitterHandle() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", twitterHandle: "@coachsmith"),
      makeCoach(id: "2", twitterHandle: nil),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "coachsmith"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
  }

  func testSearchFilter_diacriticInsensitive_plainQueryMatchesAccentedName() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "Carlos", lastName: "Muñoz"),
      makeCoach(id: "2", firstName: "Jane", lastName: "Doe"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "munoz"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.lastName, "Muñoz")
  }

  func testSearchFilter_diacriticInsensitive_accentedQueryMatchesPlainName() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "Carlos", lastName: "Munoz"),
      makeCoach(id: "2", firstName: "Jane", lastName: "Doe"),
    ]

    await sut.loadCoaches()
    sut.filters.searchText = "muñoz"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.lastName, "Munoz")
  }

  func testSearchFilter_caseInsensitive() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach(firstName: "John")]

    await sut.loadCoaches()
    sut.filters.searchText = "JOHN"

    XCTAssertEqual(sut.filteredCoaches.count, 1)
  }

  // MARK: - Role Filter Tests

  func testRoleFilter_narrowsToSelectedRole() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", position: "head"),
      makeCoach(id: "2", position: "assistant"),
      makeCoach(id: "3", position: "recruiting"),
    ]

    await sut.loadCoaches()
    sut.filters.role = .head

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.id, "1")
  }

  // MARK: - Last Contact Filter Tests

  func testLastContactFilter_excludesOldContacts() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", lastContactDate: ISO8601DateFormatter().string(from: Date())),
      makeCoach(id: "2", lastContactDate: "2025-01-01T00:00:00Z"),
    ]

    await sut.loadCoaches()
    sut.filters.lastContactDays = 7

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.id, "1")
  }

  func testLastContactFilter_excludesNilDates() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", lastContactDate: ISO8601DateFormatter().string(from: Date())),
      makeCoach(id: "2", lastContactDate: nil),
    ]

    await sut.loadCoaches()
    sut.filters.lastContactDays = 30

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.id, "1")
  }

  // MARK: - Sort Tests

  func testSortByName() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", lastName: "Zimmerman"),
      makeCoach(id: "2", lastName: "Adams"),
    ]

    await sut.loadCoaches()
    sut.filters.sortBy = .name

    XCTAssertEqual(sut.filteredCoaches.first?.id, "2")
    XCTAssertEqual(sut.filteredCoaches.last?.id, "1")
  }

  func testSortBySchool() async {
    let school1 = makeSchool(id: "s1", name: "Zebra University")
    let school2 = makeSchool(id: "s2", name: "Alpha College")
    mockService.stubbedSchools = [school1, school2]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", schoolId: "s1"),
      makeCoach(id: "2", schoolId: "s2"),
    ]

    await sut.loadCoaches()
    sut.filters.sortBy = .school

    XCTAssertEqual(sut.filteredCoaches.first?.id, "2")
  }

  func testSortByLastContacted() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", lastContactDate: "2026-01-01T00:00:00Z"),
      makeCoach(id: "2", lastContactDate: "2026-02-01T00:00:00Z"),
    ]

    await sut.loadCoaches()
    sut.filters.sortBy = .lastContacted

    XCTAssertEqual(sut.filteredCoaches.first?.id, "2")
  }

  // MARK: - Active Filter Count Tests

  func testActiveFilterCount_noFilters() {
    XCTAssertEqual(sut.activeFilterCount, 0)
  }

  func testActiveFilterCount_allFilters() {
    sut.filters.role = .head
    sut.filters.lastContactDays = 30

    XCTAssertEqual(sut.activeFilterCount, 2)
  }

  // MARK: - Clear Filters Tests

  func testClearFilters_resetsAll() {
    sut.filters.searchText = "test"
    sut.filters.role = .head
    sut.filters.lastContactDays = 30

    sut.clearFilters()

    XCTAssertEqual(sut.filters.searchText, "")
    XCTAssertNil(sut.filters.role)
    XCTAssertNil(sut.filters.lastContactDays)
    XCTAssertEqual(sut.filters.sortBy, .name)
  }

  // MARK: - Cached filteredCoaches Staleness Tests
  // filteredCoaches is a cached stored property (Phase 3.3), recomputed via
  // didSet on allCoaches/allSchools/filters — not read live.

  func testFilteredCoaches_UpdatesWhenAllCoachesReassigned_WithoutTouchingFilters() {
    sut.allCoaches = [makeCoach(id: "1", position: "head")]
    sut.filters.role = .head
    XCTAssertEqual(sut.filteredCoaches.count, 1)

    sut.allCoaches = [
      makeCoach(id: "2", position: "head"),
      makeCoach(id: "3", position: "assistant")
    ]

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.id, "2")
  }

  func testFilteredCoaches_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = makeCoach(id: "keep", position: "head")
    let remove = makeCoach(id: "remove", position: "head")
    sut.allCoaches = [keep, remove]
    sut.filters.role = .head
    XCTAssertEqual(sut.filteredCoaches.count, 2)

    sut.confirmDelete(remove)
    await sut.deleteCoach()

    XCTAssertEqual(sut.filteredCoaches.count, 1)
    XCTAssertEqual(sut.filteredCoaches.first?.id, "keep")
  }

  func testFilteredCoaches_SortBySchoolUpdatesWhenSchoolsAssignedAfterSortSet() {
    sut.allCoaches = [
      makeCoach(id: "1", lastName: "A", schoolId: "s1"),
      makeCoach(id: "2", lastName: "B", schoolId: "s2")
    ]
    sut.filters.sortBy = .school
    // No schools loaded yet — schoolName(for:) falls back to a placeholder, both equal.
    let beforeOrder = sut.filteredCoaches.map(\.id)
    XCTAssertEqual(Set(beforeOrder), ["1", "2"])

    sut.allSchools = [
      makeSchool(id: "s1", name: "Zeta University"),
      makeSchool(id: "s2", name: "Alpha College")
    ]

    XCTAssertEqual(sut.filteredCoaches.map(\.id), ["2", "1"])
  }

  // MARK: - List Fetch Caching Tests (Phase 3.6)

  func testLoadCoaches_SecondLoad_UsesCacheAndSkipsService() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach(id: "1")]

    await sut.loadCoaches()
    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)

    mockService.stubbedCoaches = [makeCoach(id: "2")]
    await sut.loadCoaches()

    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)
    XCTAssertEqual(sut.allCoaches.first?.id, "1")
  }

  func testDeleteCoach_InvalidatesListCache_NextLoadRefetches() async {
    let coach = makeCoach(id: "1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    await sut.loadCoaches()
    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)

    sut.confirmDelete(coach)
    await sut.deleteCoach()

    mockService.stubbedCoaches = []
    await sut.loadCoaches()

    XCTAssertEqual(mockService.fetchCoachesCallCount, 2)
  }

  func testAddCoachViewModel_CreateCoach_InvalidatesCoachesListCache() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [makeCoach(id: "1")]
    await sut.loadCoaches()
    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)

    // Simulate what AddCoachViewModel/AddInteractionViewModel do on creation:
    // invalidate the same cache key via the shared ListCacheKeys builder.
    await mockCache.remove(forKey: ListCacheKeys.coaches(familyUnitId: "family-1"))

    mockService.stubbedCoaches = [makeCoach(id: "1"), makeCoach(id: "2")]
    await sut.loadCoaches()

    XCTAssertEqual(mockService.fetchCoachesCallCount, 2)
    XCTAssertEqual(sut.allCoaches.count, 2)
  }

  // MARK: - Delete Tests

  func testDeleteCoach_callsServiceAndRemovesFromList() async {
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]

    await sut.loadCoaches()
    XCTAssertEqual(sut.allCoaches.count, 1)

    sut.confirmDelete(coach)
    XCTAssertTrue(sut.showDeleteConfirmation)
    XCTAssertEqual(sut.coachToDelete?.id, "coach-1")

    await sut.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedCoachId, "coach-1")
    XCTAssertTrue(sut.allCoaches.isEmpty)
    XCTAssertFalse(sut.showDeleteConfirmation)
    XCTAssertNil(sut.coachToDelete)
  }

  func testDeleteCoach_fallbackToCascade() async {
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    mockService.shouldThrowDeleteCoach = true

    await sut.loadCoaches()
    sut.confirmDelete(coach)
    await sut.deleteCoach()

    XCTAssertEqual(mockService.deleteCoachCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteCoachCallCount, 1)
    XCTAssertTrue(sut.allCoaches.isEmpty)
  }

  func testDeleteCoach_bothFail_setsErrorMessage() async {
    let coach = makeCoach(id: "coach-1")
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [coach]
    mockService.shouldThrowDeleteCoach = true
    mockService.shouldThrowCascadeDelete = true

    await sut.loadCoaches()
    sut.confirmDelete(coach)
    await sut.deleteCoach()

    XCTAssertNotNil(sut.deleteErrorMessage)
    XCTAssertEqual(sut.allCoaches.count, 1)
  }

  // MARK: - School Name Lookup Tests

  func testSchoolName_returnsName() async {
    mockService.stubbedSchools = [makeSchool(id: "s1", name: "Test University")]
    mockService.stubbedCoaches = []

    await sut.loadCoaches()

    XCTAssertEqual(sut.schoolName(for: "s1"), "Test University")
  }

  func testSchoolName_unknownId_returnsDefault() {
    XCTAssertEqual(sut.schoolName(for: "nonexistent"), "Unknown School")
  }

  // MARK: - Result Count Tests

  func testResultCount_reflectsFilteredCoaches() async {
    mockService.stubbedSchools = [makeSchool()]
    mockService.stubbedCoaches = [
      makeCoach(id: "1", firstName: "John", email: "coach1@school.edu"),
      makeCoach(id: "2", firstName: "Jane", email: "coach2@school.edu"),
    ]

    await sut.loadCoaches()
    XCTAssertEqual(sut.resultCount, 2)

    sut.filters.searchText = "john"
    XCTAssertEqual(sut.resultCount, 1)
  }
}
