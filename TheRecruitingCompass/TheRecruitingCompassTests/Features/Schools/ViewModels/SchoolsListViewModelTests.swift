import XCTest
import CoreLocation
@testable import TheRecruitingCompass

@MainActor
final class SchoolsListViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: SchoolsListViewModel!
  private var mockService: MockSchoolsService!
  private var mockAuthManager: MockAuthManager!
  private var mockFamilyManager: FamilyManager!
  private var mockFamilyService: MockFamilyService!
  private var mockInteractionsService: MockInteractionsService!
  private var mockEventsService: MockEventsService!
  private var mockCache: InMemoryCache!

  override func setUp() async throws {
    mockService = MockSchoolsService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockInteractionsService = MockInteractionsService()
    mockEventsService = MockEventsService()
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

    let athleteMember = FamilyMember(
      id: "member-1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    mockFamilyManager.currentMember = athleteMember
    // Enables `selectedAthlete` so the Visited event fetch (keyed by athlete userId) resolves.
    mockFamilyManager.familyMembers = [athleteMember]
    mockFamilyManager.selectedAthleteId = athleteMember.id

    sut = SchoolsListViewModel(
      schoolsService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager,
      interactionsService: mockInteractionsService,
      eventsService: mockEventsService,
      cache: mockCache
    )
  }

  override func tearDown() async throws {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    mockFamilyManager = nil
    mockFamilyService = nil
    mockInteractionsService = nil
    mockEventsService = nil
    mockCache = nil
  }

  // MARK: - Test Helpers

  private func makeSchool(
    id: String = "school-1",
    name: String = "Stanford University",
    location: String? = "Stanford, CA",
    city: String? = "Stanford",
    state: String? = "CA",
    division: String? = "D1",
    conference: String? = "Pac-12",
    isFavorite: Bool = false,
    status: String = "interested",
    notes: String? = nil,
    fitScore: Double? = 85,
    latitude: Double? = 37.4275,
    longitude: Double? = -122.1697
  ) -> School {
    School(
      id: id,
      userId: "user-1",
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: nil,
      isFavorite: isFavorite,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: status,
      statusChangedAt: "2026-02-01T10:00:00Z",
      notes: notes,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: latitude != nil && longitude != nil ? AcademicInfo(
        gpaRequirement: nil,
        satRequirement: nil,
        actRequirement: nil,
        additionalRequirements: nil,
        address: nil,
        city: city,
        state: state,
        latitude: latitude,
        longitude: longitude,
        studentSize: 17000,
        baseballFacilityAddress: nil,
        mascot: nil,
        undergradSize: nil,
        carnegieSize: nil,
        tuitionInState: nil,
        tuitionOutOfState: nil,
        admissionRate: nil,
        distanceFromHome: nil
      ) : nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: fitScore,
      fitTier: nil,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - Visited Analytics (real visits, not status)

  private func makeVisitInteraction(
    id: String = UUID().uuidString,
    schoolId: String,
    type: InteractionType = .inPersonVisit
  ) -> Interaction {
    Interaction(
      id: id,
      type: type,
      direction: .inbound,
      schoolId: schoolId,
      coachId: nil,
      subject: nil,
      content: nil,
      sentiment: nil,
      occurredAt: "2026-02-01T10:00:00Z",
      loggedBy: "user-1",
      attachments: nil,
      familyUnitId: "family-1",
      createdAt: "2026-02-01T10:00:00Z",
      updatedAt: nil
    )
  }

  func testVisitedCount_statusAloneNotCounted() async {
    mockService.stubbedSchools = [
      makeSchool(id: "1", status: "official_visit_scheduled"),
      makeSchool(id: "2", status: "committed"),
      makeSchool(id: "3", status: "official_visit_invited")
    ]

    await sut.loadSchools()

    XCTAssertEqual(sut.analytics.visitedCount, 0)
  }

  func testVisitedCount_countsInPersonVisitInteraction() async {
    mockService.stubbedSchools = [makeSchool(id: "1"), makeSchool(id: "2")]
    mockInteractionsService.mockInteractions = [makeVisitInteraction(schoolId: "1")]

    await sut.loadSchools()

    XCTAssertEqual(sut.analytics.visitedCount, 1)
    XCTAssertTrue(sut.visitedSchoolIds.contains("1"))
  }

  func testVisitedCount_excludesVirtualMeeting() async {
    mockService.stubbedSchools = [makeSchool(id: "1")]
    mockInteractionsService.mockInteractions = [
      makeVisitInteraction(schoolId: "1", type: .virtualMeeting)
    ]

    await sut.loadSchools()

    XCTAssertEqual(sut.analytics.visitedCount, 0)
  }

  func testVisitedCount_pastVisitEventCounts_futureDoesNot() async {
    mockService.stubbedSchools = [makeSchool(id: "1"), makeSchool(id: "2")]
    mockEventsService.stubbedEvents = [
      FullEvent.mock(id: "e1", type: "official_visit", startDate: "2020-01-01", schoolId: "1"),
      FullEvent.mock(id: "e2", type: "unofficial_visit", startDate: "2999-01-01", schoolId: "2")
    ]

    await sut.loadSchools()

    XCTAssertEqual(sut.analytics.visitedCount, 1)
    XCTAssertTrue(sut.visitedSchoolIds.contains("1"))
    XCTAssertFalse(sut.visitedSchoolIds.contains("2"))
  }

  func testVisitedCount_dedupesInteractionAndEvent() async {
    mockService.stubbedSchools = [makeSchool(id: "1")]
    mockInteractionsService.mockInteractions = [makeVisitInteraction(schoolId: "1")]
    mockEventsService.stubbedEvents = [
      FullEvent.mock(id: "e1", type: "official_visit", startDate: "2020-01-01", schoolId: "1")
    ]

    await sut.loadSchools()

    XCTAssertEqual(sut.analytics.visitedCount, 1)
  }

  // MARK: - Loading Tests

  func testLoadSchools_Success() async {
    let schools = [makeSchool(id: "1"), makeSchool(id: "2")]
    mockService.stubbedSchools = schools

    await sut.loadSchools()

    XCTAssertEqual(sut.allSchools.count, 2)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
  }

  func testLoadSchools_Failure() async {
    mockService.shouldThrowError = true

    await sut.loadSchools()

    XCTAssertTrue(sut.allSchools.isEmpty)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to load schools. Please try again.")
  }

  func testLoadSchools_NoFamilyUnit() async {
    mockFamilyManager.currentMember = nil

    await sut.loadSchools()

    XCTAssertTrue(sut.allSchools.isEmpty)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Unable to load schools. Please try again.")
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 0)
  }

  // MARK: - Search Tests

  func testSearch_ByName() {
    sut.allSchools = [
      makeSchool(id: "1", name: "Stanford University", location: "Stanford, CA", city: "Stanford", state: "CA"),
      makeSchool(id: "2", name: "Harvard University", location: "Cambridge, MA", city: "Cambridge", state: "MA"),
      makeSchool(id: "3", name: "MIT", location: "Cambridge, MA", city: "Cambridge", state: "MA")
    ]

    sut.filters.searchText = "stanford"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.name, "Stanford University")
  }

  func testSearch_ByLocation() {
    sut.allSchools = [
      makeSchool(id: "1", name: "School A", location: "Stanford, CA"),
      makeSchool(id: "2", name: "School B", location: "Boston, MA")
    ]

    sut.filters.searchText = "boston"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.name, "School B")
  }

  func testSearch_ByCity() {
    sut.allSchools = [
      makeSchool(id: "1", city: "Stanford"),
      makeSchool(id: "2", city: "Cambridge")
    ]

    sut.filters.searchText = "cambridge"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.city, "Cambridge")
  }

  func testSearch_ByState() {
    sut.allSchools = [
      makeSchool(id: "1", name: "School A", location: "San Diego, CA", city: "San Diego", state: "CA"),
      makeSchool(id: "2", name: "School B", location: "Boston, MA", city: "Boston", state: "MA")
    ]

    sut.filters.searchText = "ca"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.state, "CA")
  }

  func testSearch_ByConference() {
    sut.allSchools = [
      makeSchool(id: "1", conference: "Pac-12"),
      makeSchool(id: "2", conference: "Big Ten")
    ]

    sut.filters.searchText = "pac"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.conference, "Pac-12")
  }

  func testSearch_ByNotes() {
    sut.allSchools = [
      makeSchool(id: "1", notes: "Great academic program"),
      makeSchool(id: "2", notes: "Strong athletics")
    ]

    sut.filters.searchText = "academic"

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.id, "1")
  }

  // MARK: - Filter Tests: Division

  func testFilter_Division() {
    sut.allSchools = [
      makeSchool(id: "1", division: "D1"),
      makeSchool(id: "2", division: "D2"),
      makeSchool(id: "3", division: "D3")
    ]

    sut.filters.division = .d1

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.division, "D1")
  }

  // MARK: - Filter Tests: Status

  func testFilter_Status() {
    sut.allSchools = [
      makeSchool(id: "1", status: "interested"),
      makeSchool(id: "2", status: "contacted"),
      makeSchool(id: "3", status: "offer_received")
    ]

    sut.filters.status = .contacted

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.status, "contacted")
  }

  // MARK: - Filter Tests: State

  func testFilter_State() {
    sut.allSchools = [
      makeSchool(id: "1", state: "CA"),
      makeSchool(id: "2", state: "NY"),
      makeSchool(id: "3", state: "CA")
    ]

    sut.filters.state = "CA"

    XCTAssertEqual(sut.filteredSchools.count, 2)
    XCTAssertTrue(sut.filteredSchools.allSatisfy { $0.state == "CA" })
  }

  // MARK: - Filter Tests: Favorites

  func testFilter_FavoritesOnly() {
    sut.allSchools = [
      makeSchool(id: "1", isFavorite: true),
      makeSchool(id: "2", isFavorite: false),
      makeSchool(id: "3", isFavorite: true)
    ]

    sut.filters.isFavoritesOnly = true

    XCTAssertEqual(sut.filteredSchools.count, 2)
    XCTAssertTrue(sut.filteredSchools.allSatisfy { $0.isFavorite })
  }

  // MARK: - Filter Tests: Fit Score

  func testFilter_FitScoreMin() {
    sut.allSchools = [
      makeSchool(id: "1", fitScore: 85),
      makeSchool(id: "2", fitScore: 65),
      makeSchool(id: "3", fitScore: 45)
    ]

    sut.filters.fitScoreMin = 70

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.fitScore, 85)
  }

  func testFilter_FitScoreMax() {
    sut.allSchools = [
      makeSchool(id: "1", fitScore: 85),
      makeSchool(id: "2", fitScore: 65),
      makeSchool(id: "3", fitScore: 45)
    ]

    sut.filters.fitScoreMax = 70

    XCTAssertEqual(sut.filteredSchools.count, 2)
    XCTAssertTrue(sut.filteredSchools.allSatisfy { ($0.fitScore ?? 0) <= 70 })
  }

  func testFilter_FitScoreRange() {
    sut.allSchools = [
      makeSchool(id: "1", fitScore: 85),
      makeSchool(id: "2", fitScore: 65),
      makeSchool(id: "3", fitScore: 45)
    ]

    sut.filters.fitScoreMin = 50
    sut.filters.fitScoreMax = 70

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.fitScore, 65)
  }

  // MARK: - Filter Tests: Distance

  func testFilter_Distance_WithHomeLocation() {
    sut.homeLocation = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)
    sut.allSchools = [
      makeSchool(id: "1", latitude: 37.4275, longitude: -122.1697),
      makeSchool(id: "2", latitude: 42.3601, longitude: -71.0589)
    ]

    sut.filters.maxDistance = 50

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.id, "1")
  }

  func testFilter_Distance_WithoutHomeLocation() {
    sut.homeLocation = nil
    sut.allSchools = [
      makeSchool(id: "1", latitude: 37.4275, longitude: -122.1697),
      makeSchool(id: "2", latitude: 42.3601, longitude: -71.0589)
    ]

    sut.filters.maxDistance = 50

    XCTAssertEqual(sut.filteredSchools.count, 2)
  }

  // MARK: - Sort Tests

  func testSort_NameAZ() {
    sut.allSchools = [
      makeSchool(id: "1", name: "Yale"),
      makeSchool(id: "2", name: "Harvard"),
      makeSchool(id: "3", name: "MIT")
    ]

    sut.filters.sortBy = .nameAZ

    let names = sut.filteredSchools.map { $0.name }
    XCTAssertEqual(names, ["Harvard", "MIT", "Yale"])
  }

  func testSort_FitScore() {
    sut.allSchools = [
      makeSchool(id: "1", fitScore: 65),
      makeSchool(id: "2", fitScore: 85),
      makeSchool(id: "3", fitScore: 45)
    ]

    sut.filters.sortBy = .fitScore

    let scores = sut.filteredSchools.compactMap { $0.fitScore }
    XCTAssertEqual(scores, [85, 65, 45])
  }

  func testSort_Distance() {
    sut.homeLocation = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)
    sut.allSchools = [
      makeSchool(id: "1", name: "Far", latitude: 42.3601, longitude: -71.0589),
      makeSchool(id: "2", name: "Near", latitude: 37.4275, longitude: -122.1697)
    ]

    sut.filters.sortBy = .distance

    let names = sut.filteredSchools.map { $0.name }
    XCTAssertEqual(names.first, "Near")
  }

  // MARK: - Delete Tests

  func testDelete_Success() async {
    let school = makeSchool(id: "school-1")
    sut.allSchools = [school]
    sut.confirmDelete(school: school)

    XCTAssertEqual(sut.schoolToDelete?.id, "school-1")
    XCTAssertTrue(sut.showDeleteConfirmation)

    await sut.deleteSchool()

    XCTAssertTrue(sut.allSchools.isEmpty)
    XCTAssertEqual(mockService.deleteSchoolCallCount, 1)
    XCTAssertNotNil(sut.successMessage)
    XCTAssertTrue(sut.showSuccessToast)
  }

  func testDelete_CascadeFallback() async {
    let school = makeSchool(id: "school-1")
    sut.allSchools = [school]
    mockService.simpleDeleteShouldFail = true
    sut.confirmDelete(school: school)

    await sut.deleteSchool()

    XCTAssertTrue(sut.allSchools.isEmpty)
    XCTAssertEqual(mockService.deleteSchoolCallCount, 1)
    XCTAssertEqual(mockService.cascadeDeleteSchoolCallCount, 1)
    XCTAssertNotNil(sut.successMessage)
  }

  func testDelete_Failure() async {
    let school = makeSchool(id: "school-1")
    sut.allSchools = [school]
    mockService.shouldThrowError = true
    mockService.stubbedDeleteResult = DeleteResult(isCascadeUsed: false, deletedInteractions: 0, deletedNotes: 0)
    sut.confirmDelete(school: school)

    await sut.deleteSchool()

    XCTAssertFalse(sut.allSchools.isEmpty)
    XCTAssertNotNil(sut.deleteErrorMessage)
  }

  // MARK: - Toggle Favorite Tests

  func testToggleFavorite_Success() async {
    let school = makeSchool(id: "school-1", isFavorite: false)
    sut.allSchools = [school]

    await sut.toggleFavorite(school: school)

    XCTAssertTrue(sut.allSchools.first!.isFavorite)
    XCTAssertEqual(mockService.toggleFavoriteCallCount, 1)
    XCTAssertNil(sut.errorMessage)
  }

  func testToggleFavorite_FailureRevertsChange() async {
    let school = makeSchool(id: "school-1", isFavorite: false)
    sut.allSchools = [school]
    mockService.shouldThrowError = true

    await sut.toggleFavorite(school: school)

    XCTAssertFalse(sut.allSchools.first!.isFavorite)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Clear Filters Tests

  func testClearFilters() {
    sut.filters.searchText = "test"
    sut.filters.division = .d1
    sut.filters.status = .contacted
    sut.filters.state = "CA"
    sut.filters.isFavoritesOnly = true
    sut.filters.fitScoreMin = 70
    sut.filters.maxDistance = 100
    let originalSort = sut.filters.sortBy

    sut.clearFilters()

    XCTAssertTrue(sut.filters.searchText.isEmpty)
    XCTAssertNil(sut.filters.division)
    XCTAssertNil(sut.filters.status)
    XCTAssertNil(sut.filters.state)
    XCTAssertFalse(sut.filters.isFavoritesOnly)
    XCTAssertNil(sut.filters.fitScoreMin)
    XCTAssertNil(sut.filters.maxDistance)
    XCTAssertEqual(sut.filters.sortBy, originalSort)
  }

  // MARK: - Computed Properties Tests

  func testAvailableStates() {
    sut.allSchools = [
      makeSchool(id: "1", state: "CA"),
      makeSchool(id: "2", state: "NY"),
      makeSchool(id: "3", state: "CA"),
      makeSchool(id: "4", state: "TX")
    ]

    let states = sut.availableStates

    XCTAssertEqual(states.count, 3)
    XCTAssertTrue(states.contains("CA"))
    XCTAssertTrue(states.contains("NY"))
    XCTAssertTrue(states.contains("TX"))
    XCTAssertEqual(states, states.sorted())
  }

  func testResultCount() {
    sut.allSchools = [
      makeSchool(id: "1", division: "D1"),
      makeSchool(id: "2", division: "D2")
    ]
    sut.filters.division = .d1

    XCTAssertEqual(sut.resultCount, 1)
  }

  func testActiveFilterCount() {
    XCTAssertEqual(sut.activeFilterCount, 0)

    sut.filters.searchText = "test"
    XCTAssertEqual(sut.activeFilterCount, 1)

    sut.filters.division = .d1
    XCTAssertEqual(sut.activeFilterCount, 2)

    sut.filters.isFavoritesOnly = true
    XCTAssertEqual(sut.activeFilterCount, 3)
  }

  func testShowWarningBanner() {
    sut.allSchools = Array(repeating: makeSchool(id: "1"), count: 29)
    XCTAssertFalse(sut.showWarningBanner)

    sut.allSchools = Array(repeating: makeSchool(id: "1"), count: 30)
    XCTAssertTrue(sut.showWarningBanner)
  }

  // MARK: - Cached filteredSchools Staleness Tests
  // filteredSchools is a cached stored property (Phase 3.3), recomputed via
  // didSet on allSchools/filters and homeLocation's setter — not read live.
  // These tests exist to catch a missed invalidation hook, which would silently
  // leave filteredSchools stale after a mutation.

  func testFilteredSchools_UpdatesWhenAllSchoolsReassigned_WithoutTouchingFilters() {
    sut.allSchools = [makeSchool(id: "1", division: "D1")]
    sut.filters.division = .d1
    XCTAssertEqual(sut.filteredSchools.count, 1)

    // Reassign allSchools wholesale (e.g. a reload) without touching filters again.
    sut.allSchools = [
      makeSchool(id: "2", division: "D1"),
      makeSchool(id: "3", division: "D2")
    ]

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.id, "2")
  }

  func testFilteredSchools_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = makeSchool(id: "keep", isFavorite: true)
    let remove = makeSchool(id: "remove", isFavorite: true)
    sut.allSchools = [keep, remove]
    sut.filters.isFavoritesOnly = true
    XCTAssertEqual(sut.filteredSchools.count, 2)

    sut.confirmDelete(school: remove)
    await sut.deleteSchool()

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.id, "keep")
  }

  func testFilteredSchools_UpdatesAfterToggleFavoriteWithoutExplicitRecompute() async {
    let school = makeSchool(id: "1", isFavorite: false)
    sut.allSchools = [school]
    sut.filters.isFavoritesOnly = true
    XCTAssertEqual(sut.filteredSchools.count, 0)

    await sut.toggleFavorite(school: school)

    XCTAssertEqual(sut.filteredSchools.count, 1)
  }

  func testFilteredSchools_UpdatesWhenHomeLocationSetAfterDistanceFilter() {
    sut.allSchools = [
      makeSchool(id: "1", latitude: 37.4275, longitude: -122.1697),
      makeSchool(id: "2", latitude: 42.3601, longitude: -71.0589)
    ]
    sut.filters.maxDistance = 50
    // No home location yet — distance filter is a no-op per existing behavior.
    XCTAssertEqual(sut.filteredSchools.count, 2)

    sut.homeLocation = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)

    XCTAssertEqual(sut.filteredSchools.count, 1)
    XCTAssertEqual(sut.filteredSchools.first?.id, "1")
  }

  // MARK: - List Fetch Caching Tests (Phase 3.6)

  func testLoadSchools_SecondLoad_UsesCacheAndSkipsService() async {
    mockService.stubbedSchools = [makeSchool(id: "1")]

    await sut.loadSchools()
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)

    mockService.stubbedSchools = [makeSchool(id: "2")]
    await sut.loadSchools()

    // Second load reads the cache — service not called again, list unchanged.
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
    XCTAssertEqual(sut.allSchools.first?.id, "1")
  }

  func testDeleteSchool_InvalidatesListCache_NextLoadRefetches() async {
    let school = makeSchool(id: "1")
    mockService.stubbedSchools = [school]
    await sut.loadSchools()
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)

    sut.confirmDelete(school: school)
    await sut.deleteSchool()

    mockService.stubbedSchools = []
    await sut.loadSchools()

    XCTAssertEqual(mockService.fetchSchoolsCallCount, 2)
  }

  func testToggleFavorite_InvalidatesListCache_NextLoadRefetches() async {
    let school = makeSchool(id: "1", isFavorite: false)
    mockService.stubbedSchools = [school]
    await sut.loadSchools()
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)

    await sut.toggleFavorite(school: school)

    mockService.stubbedSchools = [makeSchool(id: "1", isFavorite: true)]
    await sut.loadSchools()

    XCTAssertEqual(mockService.fetchSchoolsCallCount, 2)
  }

  func testAddSchoolViewModel_CreateSchool_InvalidatesSchoolsListCache() async throws {
    mockService.stubbedSchools = [makeSchool(id: "1")]
    await sut.loadSchools()
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)

    // Simulate what AddSchoolViewModel does on successful creation: invalidate
    // the same cache key via the shared ListCacheKeys builder.
    await mockCache.remove(forKey: ListCacheKeys.schools(familyUnitId: "family-1"))

    mockService.stubbedSchools = [makeSchool(id: "1"), makeSchool(id: "2")]
    await sut.loadSchools()

    XCTAssertEqual(mockService.fetchSchoolsCallCount, 2)
    XCTAssertEqual(sut.allSchools.count, 2)
  }

  // MARK: - Distance Caching Tests

  func testCachedDistance() {
    let home = CLLocationCoordinate2D(latitude: 37.3861, longitude: -122.0839)
    let school = makeSchool(id: "1", latitude: 37.4275, longitude: -122.1697)

    let distance1 = sut.cachedDistance(for: school, from: home)
    let distance2 = sut.cachedDistance(for: school, from: home)

    XCTAssertNotNil(distance1)
    XCTAssertEqual(distance1, distance2)
  }
}
