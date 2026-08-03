import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OffersListViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: OffersListViewModel!
  var mockService: MockOffersService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!
  var familyManager: FamilyManager!

  override func setUp() async throws {
    mockService = MockOffersService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockAuthManager.setMockUser(User(
      id: "test-user-id",
      email: "test@example.com",
      emailConfirmedAt: "2025-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      role: .player
    ))
    familyManager = FamilyManager(
      familyService: mockFamilyService,
      authManager: mockAuthManager
    )
    viewModel = OffersListViewModel(
      offersService: mockService,
      familyManager: familyManager,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
    mockFamilyService = nil
    familyManager = nil
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertTrue(viewModel.allOffers.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.selectedOfferIds.isEmpty)
    XCTAssertFalse(viewModel.showAddForm)
    XCTAssertFalse(viewModel.showComparison)
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertNil(viewModel.successMessage)
  }

  // MARK: - loadOffers Tests

  func testLoadOffers_Success() async {
    mockService.stubbedOffers = [
      makeTestOffer(id: "1"),
      makeTestOffer(id: "2")
    ]

    await viewModel.loadOffers()

    XCTAssertEqual(viewModel.allOffers.count, 2)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(mockService.fetchOffersCallCount, 1)
  }

  func testLoadOffers_Error() async {
    mockService.shouldThrowFetchError = true

    await viewModel.loadOffers()

    XCTAssertTrue(viewModel.allOffers.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage!.contains("Failed to load offers"))
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadOffers_NoUser_SetsError() async {
    mockAuthManager.user = nil

    await viewModel.loadOffers()

    XCTAssertEqual(viewModel.errorMessage, "Unable to load offers. Please try again.")
    XCTAssertEqual(mockService.fetchOffersCallCount, 0)
  }

  func testLoadOffers_ClearsErrorOnRetry() async {
    mockService.shouldThrowFetchError = true
    await viewModel.loadOffers()
    XCTAssertNotNil(viewModel.errorMessage)

    mockService.shouldThrowFetchError = false
    mockService.stubbedOffers = [makeTestOffer(id: "1")]
    await viewModel.loadOffers()

    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.allOffers.count, 1)
  }

  // MARK: - createOffer Tests

  func testCreateOffer_Success() async {
    let created = makeTestOffer(id: "new-1")
    mockService.stubbedCreatedOffer = created
    viewModel.formState.schoolId = "school-1"

    await viewModel.createOffer()

    XCTAssertEqual(viewModel.allOffers.count, 1)
    XCTAssertEqual(viewModel.allOffers.first?.id, "new-1")
    XCTAssertFalse(viewModel.showAddForm)
    XCTAssertEqual(viewModel.successMessage, "Offer logged successfully")
    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertEqual(mockService.createOfferCallCount, 1)
  }

  func testCreateOffer_ResetsFormAfterSuccess() async {
    let created = makeTestOffer(id: "new-1")
    mockService.stubbedCreatedOffer = created
    viewModel.formState.schoolId = "school-1"
    viewModel.formState.offerType = .fullRide
    viewModel.formState.notes = "Test notes"

    await viewModel.createOffer()

    XCTAssertNil(viewModel.formState.schoolId)
    XCTAssertEqual(viewModel.formState.offerType, .scholarship)
    XCTAssertTrue(viewModel.formState.notes.isEmpty)
  }

  func testCreateOffer_ValidationFailure_DoesNotCallService() async {
    // formState.schoolId is nil by default, which triggers validation error
    await viewModel.createOffer()

    XCTAssertEqual(mockService.createOfferCallCount, 0)
    XCTAssertTrue(viewModel.allOffers.isEmpty)
  }

  func testCreateOffer_NoUser_DoesNotCallService() async {
    mockAuthManager.user = nil
    viewModel.formState.schoolId = "school-1"

    await viewModel.createOffer()

    XCTAssertEqual(mockService.createOfferCallCount, 0)
  }

  func testCreateOffer_ServiceError() async {
    mockService.shouldThrowCreateError = true
    viewModel.formState.schoolId = "school-1"

    await viewModel.createOffer()

    XCTAssertTrue(viewModel.allOffers.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage!.contains("Failed to save offer"))
    XCTAssertFalse(viewModel.isSubmitting)
  }

  // MARK: - deleteOffer Tests

  func testDeleteOffer_Success() async {
    let offer = makeTestOffer(id: "del-1")
    viewModel.allOffers = [offer]
    viewModel.confirmDelete(offer)

    await viewModel.deleteOffer()

    XCTAssertTrue(viewModel.allOffers.isEmpty)
    XCTAssertEqual(mockService.deleteOfferCallCount, 1)
    XCTAssertEqual(mockService.lastDeletedOfferId, "del-1")
    XCTAssertEqual(viewModel.successMessage, "Offer deleted")
    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertNil(viewModel.offerToDelete)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
  }

  func testDeleteOffer_Error() async {
    let offer = makeTestOffer(id: "del-2")
    viewModel.allOffers = [offer]
    viewModel.confirmDelete(offer)
    mockService.shouldThrowDeleteError = true

    await viewModel.deleteOffer()

    XCTAssertEqual(viewModel.allOffers.count, 1)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.errorMessage, "Failed to delete offer. Please try again.")
  }

  func testDeleteOffer_NoOfferToDelete_NoOp() async {
    await viewModel.deleteOffer()
    XCTAssertEqual(mockService.deleteOfferCallCount, 0)
  }

  func testDeleteOffer_ClearsConfirmationState() async {
    let offer = makeTestOffer(id: "del-4")
    viewModel.allOffers = [offer]
    viewModel.confirmDelete(offer)

    await viewModel.deleteOffer()

    XCTAssertNil(viewModel.offerToDelete)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
  }

  func testDeleteOffer_RemovesFromSelection() async {
    let offer = makeTestOffer(id: "del-3")
    viewModel.allOffers = [offer]
    viewModel.selectedOfferIds.insert("del-3")
    viewModel.confirmDelete(offer)

    await viewModel.deleteOffer()

    XCTAssertFalse(viewModel.selectedOfferIds.contains("del-3"))
  }

  // MARK: - filteredOffers Tests

  func testFilteredOffers_NoFilters_ReturnsAll() {
    viewModel.allOffers = [
      makeTestOffer(id: "1"),
      makeTestOffer(id: "2"),
      makeTestOffer(id: "3")
    ]

    XCTAssertEqual(viewModel.filteredOffers.count, 3)
  }

  func testFilteredOffers_StatusFilter() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", status: .pending),
      makeTestOffer(id: "2", status: .accepted),
      makeTestOffer(id: "3", status: .pending)
    ]
    viewModel.filters.status = .pending

    XCTAssertEqual(viewModel.filteredOffers.count, 2)
    XCTAssertTrue(viewModel.filteredOffers.allSatisfy { $0.status == .pending })
  }

  func testFilteredOffers_TypeFilter() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", offerType: .fullRide),
      makeTestOffer(id: "2", offerType: .partial),
      makeTestOffer(id: "3", offerType: .fullRide)
    ]
    viewModel.filters.offerType = .fullRide

    XCTAssertEqual(viewModel.filteredOffers.count, 2)
    XCTAssertTrue(viewModel.filteredOffers.allSatisfy { $0.offerType == .fullRide })
  }

  func testFilteredOffers_SearchBySchoolName() {
    let school = makeSchool(id: "s1", name: "UCLA")
    viewModel.schools = [school]
    viewModel.allOffers = [
      makeTestOffer(id: "1", schoolId: "s1"),
      makeTestOffer(id: "2", schoolId: "other-school")
    ]
    viewModel.filters.schoolSearch = "UCLA"

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
    XCTAssertEqual(viewModel.filteredOffers.first?.schoolId, "s1")
  }

  func testFilteredOffers_SearchCaseInsensitive() {
    let school = makeSchool(id: "s1", name: "UCLA")
    viewModel.schools = [school]
    viewModel.allOffers = [makeTestOffer(id: "1", schoolId: "s1")]
    viewModel.filters.schoolSearch = "ucla"

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
  }

  func testFilteredOffers_CombinedFilters() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", offerType: .fullRide, status: .pending),
      makeTestOffer(id: "2", offerType: .fullRide, status: .accepted),
      makeTestOffer(id: "3", offerType: .partial, status: .pending)
    ]
    viewModel.filters.status = .pending
    viewModel.filters.offerType = .fullRide

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
    XCTAssertEqual(viewModel.filteredOffers.first?.id, "1")
  }

  // MARK: - Cached filteredOffers Staleness Tests
  // filteredOffers is a cached stored property (Phase 3.3), recomputed via
  // didSet on allOffers/schools/filters — not read live.

  func testFilteredOffers_UpdatesWhenAllOffersReassigned_WithoutTouchingFilters() {
    viewModel.allOffers = [makeTestOffer(id: "1", status: .pending)]
    viewModel.filters.status = .pending
    XCTAssertEqual(viewModel.filteredOffers.count, 1)

    viewModel.allOffers = [
      makeTestOffer(id: "2", status: .pending),
      makeTestOffer(id: "3", status: .accepted)
    ]

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
    XCTAssertEqual(viewModel.filteredOffers.first?.id, "2")
  }

  func testFilteredOffers_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = makeTestOffer(id: "keep", status: .pending)
    let remove = makeTestOffer(id: "remove", status: .pending)
    viewModel.allOffers = [keep, remove]
    viewModel.filters.status = .pending
    XCTAssertEqual(viewModel.filteredOffers.count, 2)

    viewModel.confirmDelete(remove)
    await viewModel.deleteOffer()

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
    XCTAssertEqual(viewModel.filteredOffers.first?.id, "keep")
  }

  func testFilteredOffers_UpdatesWhenSchoolsAssignedAfterSearchFilterSet() {
    viewModel.allOffers = [makeTestOffer(id: "1", schoolId: "s1")]
    viewModel.filters.schoolSearch = "UCLA"
    // No schools loaded yet — schoolName(for:) falls back to "Unknown School".
    XCTAssertEqual(viewModel.filteredOffers.count, 0)

    viewModel.schools = [makeSchool(id: "s1", name: "UCLA")]

    XCTAssertEqual(viewModel.filteredOffers.count, 1)
  }

  // MARK: - Selection Tests

  func testToggleSelection_AddsOffer() {
    viewModel.toggleSelection("offer-1")
    XCTAssertTrue(viewModel.selectedOfferIds.contains("offer-1"))
  }

  func testToggleSelection_RemovesOffer() {
    viewModel.selectedOfferIds.insert("offer-1")
    viewModel.toggleSelection("offer-1")
    XCTAssertFalse(viewModel.selectedOfferIds.contains("offer-1"))
  }

  func testSelectedOffers_ReturnsMatchingOffers() {
    let offer1 = makeTestOffer(id: "1")
    let offer2 = makeTestOffer(id: "2")
    let offer3 = makeTestOffer(id: "3")
    viewModel.allOffers = [offer1, offer2, offer3]
    viewModel.selectedOfferIds = ["1", "3"]

    XCTAssertEqual(viewModel.selectedOffers.count, 2)
    let ids = viewModel.selectedOffers.map(\.id)
    XCTAssertTrue(ids.contains("1"))
    XCTAssertTrue(ids.contains("3"))
  }

  func testCanCompare_FalseWithZeroSelected() {
    XCTAssertFalse(viewModel.canCompare)
  }

  func testCanCompare_FalseWithOneSelected() {
    viewModel.selectedOfferIds = ["1"]
    XCTAssertFalse(viewModel.canCompare)
  }

  func testCanCompare_TrueWithTwoOrMore() {
    viewModel.selectedOfferIds = ["1", "2"]
    XCTAssertTrue(viewModel.canCompare)
  }

  // MARK: - Sorting Tests

  func testSortedOffers_ByOfferDate_Descending() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", offerDate: "2025-01-01"),
      makeTestOffer(id: "2", offerDate: "2025-06-15"),
      makeTestOffer(id: "3", offerDate: "2025-03-10")
    ]
    viewModel.filters.sortBy = .offerDate
    viewModel.filters.sortDirection = .descending

    let sorted = viewModel.filteredOffers
    XCTAssertEqual(sorted[0].id, "2")
    XCTAssertEqual(sorted[1].id, "3")
    XCTAssertEqual(sorted[2].id, "1")
  }

  func testSortedOffers_ByOfferDate_Ascending() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", offerDate: "2025-01-01"),
      makeTestOffer(id: "2", offerDate: "2025-06-15"),
      makeTestOffer(id: "3", offerDate: "2025-03-10")
    ]
    viewModel.filters.sortBy = .offerDate
    viewModel.filters.sortDirection = .ascending

    let sorted = viewModel.filteredOffers
    XCTAssertEqual(sorted[0].id, "1")
    XCTAssertEqual(sorted[1].id, "3")
    XCTAssertEqual(sorted[2].id, "2")
  }

  func testSortedOffers_ByPercentage_Descending() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", scholarshipPercentage: 25),
      makeTestOffer(id: "2", scholarshipPercentage: 100),
      makeTestOffer(id: "3", scholarshipPercentage: 50)
    ]
    viewModel.filters.sortBy = .percentage
    viewModel.filters.sortDirection = .descending

    let sorted = viewModel.filteredOffers
    XCTAssertEqual(sorted[0].id, "2")
    XCTAssertEqual(sorted[1].id, "3")
    XCTAssertEqual(sorted[2].id, "1")
  }

  func testSortedOffers_ByAmount_Ascending() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", scholarshipAmount: 50000),
      makeTestOffer(id: "2", scholarshipAmount: 10000),
      makeTestOffer(id: "3", scholarshipAmount: 30000)
    ]
    viewModel.filters.sortBy = .amount
    viewModel.filters.sortDirection = .ascending

    let sorted = viewModel.filteredOffers
    XCTAssertEqual(sorted[0].id, "2")
    XCTAssertEqual(sorted[1].id, "3")
    XCTAssertEqual(sorted[2].id, "1")
  }

  // MARK: - Status Counts Tests

  func testAcceptedCount() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", status: .accepted),
      makeTestOffer(id: "2", status: .pending),
      makeTestOffer(id: "3", status: .accepted)
    ]
    XCTAssertEqual(viewModel.acceptedCount, 2)
  }

  func testPendingCount() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", status: .pending),
      makeTestOffer(id: "2", status: .pending),
      makeTestOffer(id: "3", status: .declined)
    ]
    XCTAssertEqual(viewModel.pendingCount, 2)
  }

  func testDeclinedCount() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", status: .declined),
      makeTestOffer(id: "2", status: .accepted)
    ]
    XCTAssertEqual(viewModel.declinedCount, 1)
  }

  func testCountsWithMixedStatuses() {
    viewModel.allOffers = [
      makeTestOffer(id: "1", status: .accepted),
      makeTestOffer(id: "2", status: .pending),
      makeTestOffer(id: "3", status: .declined),
      makeTestOffer(id: "4", status: .expired),
      makeTestOffer(id: "5", status: .pending)
    ]
    XCTAssertEqual(viewModel.acceptedCount, 1)
    XCTAssertEqual(viewModel.pendingCount, 2)
    XCTAssertEqual(viewModel.declinedCount, 1)
  }

  // MARK: - clearFilters Tests

  func testClearFilters_ResetsAllFilters() {
    viewModel.filters.schoolSearch = "UCLA"
    viewModel.filters.status = .accepted
    viewModel.filters.offerType = .fullRide
    viewModel.filters.sortBy = .amount

    viewModel.clearFilters()

    XCTAssertTrue(viewModel.filters.schoolSearch.isEmpty)
    XCTAssertNil(viewModel.filters.status)
    XCTAssertNil(viewModel.filters.offerType)
    XCTAssertEqual(viewModel.filters.sortBy, .offerDate)
    XCTAssertEqual(viewModel.filters.sortDirection, .descending)
  }

  // MARK: - confirmDelete Tests

  func testConfirmDelete_SetsOfferAndShowsConfirmation() {
    let offer = makeTestOffer(id: "to-delete")

    viewModel.confirmDelete(offer)

    XCTAssertEqual(viewModel.offerToDelete?.id, "to-delete")
    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  // MARK: - schoolName Tests

  func testSchoolName_ReturnsNameWhenFound() {
    viewModel.schools = [makeSchool(id: "s1", name: "Stanford")]
    XCTAssertEqual(viewModel.schoolName(for: "s1"), "Stanford")
  }

  func testSchoolName_ReturnsUnknownWhenNotFound() {
    XCTAssertEqual(viewModel.schoolName(for: "missing-id"), "Unknown School")
  }

  // MARK: - Helpers

  private func makeSchool(id: String, name: String) -> School {
    School(
      id: id,
      userId: "user-1",
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
      status: "active",
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
}

// MARK: - Shared Test Helpers

func makeTestOffer(
  id: String = "offer-1",
  schoolId: String = "school-1",
  offerType: OfferType = .scholarship,
  scholarshipAmount: Double? = nil,
  scholarshipPercentage: Int? = nil,
  offerDate: String = "2025-06-01",
  deadlineDate: String? = nil,
  status: OfferStatus = .pending
) -> Offer {
  Offer(
    id: id,
    userId: "user-1",
    schoolId: schoolId,
    offerType: offerType,
    scholarshipAmount: scholarshipAmount,
    scholarshipPercentage: scholarshipPercentage,
    offerDate: offerDate,
    deadlineDate: deadlineDate,
    status: status,
    conditions: nil,
    notes: nil,
    createdAt: "2025-06-01T00:00:00Z",
    updatedAt: "2025-06-01T00:00:00Z"
  )
}
