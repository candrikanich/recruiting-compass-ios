import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OfferDetailViewModelTests: XCTestCase {
  var mockService: MockOffersService!
  var mockAuthManager: MockAuthManager!
  var sut: OfferDetailViewModel!

  override func setUp() async throws {
    mockService = MockOffersService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: "2025-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      role: .player
    ))
    let emptyCache = InMemoryCache()
    sut = OfferDetailViewModel(
      offerId: "test-offer-id",
      offersService: mockService,
      authManager: mockAuthManager,
      cache: emptyCache
    )
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertNil(sut.offer)
    XCTAssertNil(sut.school)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isEditing)
    XCTAssertFalse(sut.isUpdating)
    XCTAssertFalse(sut.isDeleting)
    XCTAssertNil(sut.activeAlert)
  }

  // MARK: - loadOffer Tests

  func testLoadOffer_Success_SetsOffer() async {
    let expected = makeTestOffer(id: "test-offer-id")
    mockService.stubbedOffer = expected

    await sut.loadOffer()

    XCTAssertEqual(sut.offer?.id, "test-offer-id")
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadOffer_Success_LoadsSchool() async {
    let offer = makeTestOffer(id: "test-offer-id", schoolId: "school-1")
    mockService.stubbedOffer = offer
    mockService.stubbedSchool = makeTestSchool(id: "school-1", name: "Test University")

    await sut.loadOffer()

    XCTAssertEqual(sut.school?.name, "Test University")
    XCTAssertEqual(mockService.fetchSchoolCallCount, 1)
  }

  func testLoadOffer_Failure_SetsErrorMessage() async {
    mockService.shouldThrowFetchOfferError = true

    await sut.loadOffer()

    XCTAssertNil(sut.offer)
    XCTAssertEqual(sut.errorMessage, "Failed to load offer details")
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadOffer_SchoolFailure_StillSetsOffer() async {
    let offer = makeTestOffer(id: "test-offer-id")
    mockService.stubbedOffer = offer
    mockService.shouldThrowFetchSchoolError = true

    await sut.loadOffer()

    XCTAssertNotNil(sut.offer)
    XCTAssertNil(sut.school)
    XCTAssertNil(sut.errorMessage)
  }

  func testLoadOffer_ClearsErrorMessage() async {
    sut.errorMessage = "Previous error"
    mockService.stubbedOffer = makeTestOffer(id: "test-offer-id")

    await sut.loadOffer()

    XCTAssertNil(sut.errorMessage)
  }

  func testLoadOffer_CallsFetchOffer() async {
    mockService.stubbedOffer = makeTestOffer(id: "test-offer-id")

    await sut.loadOffer()

    XCTAssertEqual(mockService.fetchOfferCallCount, 1)
  }

  // MARK: - startEditing Tests

  func testStartEditing_SetsIsEditing() {
    sut.offer = makeTestOffer(id: "test-offer-id", offerType: .fullRide)

    sut.startEditing()

    XCTAssertTrue(sut.isEditing)
  }

  func testStartEditing_PopulatesEditDataFromOffer() {
    sut.offer = makeTestOffer(
      id: "test-offer-id",
      offerType: .fullRide,
      scholarshipAmount: 50000,
      scholarshipPercentage: 100,
      status: .accepted
    )

    sut.startEditing()

    XCTAssertEqual(sut.editData.offerType, .fullRide)
    XCTAssertEqual(sut.editData.scholarshipAmount, 50000)
    XCTAssertEqual(sut.editData.scholarshipPercentage, 100)
    XCTAssertEqual(sut.editData.status, .accepted)
  }

  func testStartEditing_NoOffer_DoesNotSetEditing() {
    sut.offer = nil

    sut.startEditing()

    XCTAssertFalse(sut.isEditing)
  }

  // MARK: - cancelEditing Tests

  func testCancelEditing_SetsIsEditingFalse() {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()
    XCTAssertTrue(sut.isEditing)

    sut.cancelEditing()

    XCTAssertFalse(sut.isEditing)
  }

  func testCancelEditing_ResetsEditData() {
    sut.offer = makeTestOffer(id: "test-offer-id", offerType: .fullRide)
    sut.startEditing()
    XCTAssertEqual(sut.editData.offerType, .fullRide)

    sut.cancelEditing()

    XCTAssertEqual(sut.editData.offerType, .scholarship)
  }

  // MARK: - saveChanges Tests

  func testSaveChanges_Success_UpdatesOffer() async {
    sut.offer = makeTestOffer(id: "test-offer-id", offerType: .partial)
    sut.startEditing()
    let updatedOffer = makeTestOffer(id: "test-offer-id", offerType: .fullRide)
    mockService.stubbedUpdatedOffer = updatedOffer

    await sut.saveChanges()

    XCTAssertEqual(sut.offer?.offerType, .fullRide)
    XCTAssertEqual(mockService.updateOfferCallCount, 1)
  }

  func testSaveChanges_Success_SetsIsEditingFalse() async {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()
    mockService.stubbedUpdatedOffer = makeTestOffer(id: "test-offer-id")

    await sut.saveChanges()

    XCTAssertFalse(sut.isEditing)
  }

  func testSaveChanges_Failure_KeepsIsEditingTrue() async {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()
    mockService.shouldThrowUpdateError = true

    await sut.saveChanges()

    XCTAssertTrue(sut.isEditing)
  }

  func testSaveChanges_Failure_SetsActiveAlert() async {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()
    mockService.shouldThrowUpdateError = true

    await sut.saveChanges()

    if case .error = sut.activeAlert {
      // expected
    } else {
      XCTFail("Expected .error alert, got \(String(describing: sut.activeAlert))")
    }
  }

  func testSaveChanges_ManagesIsUpdating() async {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()
    mockService.stubbedUpdatedOffer = makeTestOffer(id: "test-offer-id")

    XCTAssertFalse(sut.isUpdating)

    await sut.saveChanges()

    XCTAssertFalse(sut.isUpdating)
  }

  // MARK: - deleteOffer Tests

  func testDeleteOffer_Success_CallsOnSuccess() async {
    var onSuccessCalled = false

    await sut.deleteOffer(onSuccess: { onSuccessCalled = true })

    XCTAssertTrue(onSuccessCalled)
    XCTAssertEqual(mockService.deleteOfferCallCount, 1)
  }

  func testDeleteOffer_Failure_SetsActiveAlert() async {
    mockService.shouldThrowDeleteError = true

    await sut.deleteOffer(onSuccess: {})

    if case .deleteError = sut.activeAlert {
      // expected
    } else {
      XCTFail("Expected .deleteError alert, got \(String(describing: sut.activeAlert))")
    }
  }

  func testDeleteOffer_Failure_DoesNotCallOnSuccess() async {
    mockService.shouldThrowDeleteError = true
    var onSuccessCalled = false

    await sut.deleteOffer(onSuccess: { onSuccessCalled = true })

    XCTAssertFalse(onSuccessCalled)
  }

  func testDeleteOffer_ManagesIsDeleting() async {
    XCTAssertFalse(sut.isDeleting)

    await sut.deleteOffer(onSuccess: {})

    XCTAssertFalse(sut.isDeleting)
  }

  // MARK: - confirmDelete Tests

  func testConfirmDelete_SetsActiveAlert() {
    sut.confirmDelete()

    if case .deleteConfirmation = sut.activeAlert {
      // expected
    } else {
      XCTFail("Expected .deleteConfirmation alert")
    }
  }

  // MARK: - Computed Properties Tests

  func testSchoolName_WhenSchoolSet() {
    sut.school = makeTestSchool(id: "s1", name: "Stanford")
    XCTAssertEqual(sut.schoolName, "Stanford")
  }

  func testSchoolName_WhenNoSchool() {
    XCTAssertEqual(sut.schoolName, "Unknown School")
  }

  func testFormattedOfferDate_WhenNoOffer() {
    XCTAssertEqual(sut.formattedOfferDate, "")
  }

  func testFormattedOfferDate_WhenOfferSet() {
    sut.offer = makeTestOffer(id: "1", offerDate: "2025-06-15")
    XCTAssertFalse(sut.formattedOfferDate.isEmpty)
  }

  func testFormattedDeadlineDate_WhenNoOffer() {
    XCTAssertEqual(sut.formattedDeadlineDate, "No deadline set")
  }

  func testFormattedDeadlineDate_WhenNoDeadline() {
    sut.offer = makeTestOffer(id: "1", deadlineDate: nil)
    XCTAssertEqual(sut.formattedDeadlineDate, "No deadline set")
  }

  func testFormattedDeadlineDate_WhenDeadlineSet() {
    sut.offer = makeTestOffer(id: "1", deadlineDate: "2025-12-31")
    XCTAssertNotEqual(sut.formattedDeadlineDate, "No deadline set")
  }

  func testDeadlineDisplayText_WhenNoOffer() {
    XCTAssertEqual(sut.deadlineDisplayText, "---")
  }

  func testDeadlineDisplayText_WhenNoDeadline() {
    sut.offer = makeTestOffer(id: "1", deadlineDate: nil)
    XCTAssertEqual(sut.deadlineDisplayText, "---")
  }

  func testDeadlineDisplayText_FutureDeadline() {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    let startOfTodayUTC = cal.startOfDay(for: Date())
    let futureDate = cal.date(byAdding: .day, value: 10, to: startOfTodayUTC)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = utc
    sut.offer = makeTestOffer(id: "1", deadlineDate: formatter.string(from: futureDate))
    XCTAssertEqual(sut.deadlineDisplayText, "10d")
  }

  func testDeadlineDisplayText_OverdueDeadline() {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    let startOfTodayUTC = cal.startOfDay(for: Date())
    let pastDate = cal.date(byAdding: .day, value: -5, to: startOfTodayUTC)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = utc
    sut.offer = makeTestOffer(id: "1", deadlineDate: formatter.string(from: pastDate))
    XCTAssertEqual(sut.deadlineDisplayText, "5d overdue")
  }

  // MARK: - applyCalculatorValues Tests

  func testApplyCalculatorValues_SetsEditDataValues() {
    sut.offer = makeTestOffer(id: "test-offer-id")
    sut.startEditing()

    sut.applyCalculatorValues(amount: 30000, percentage: 60)

    XCTAssertEqual(sut.editData.scholarshipAmount, 30000)
    XCTAssertEqual(sut.editData.scholarshipPercentage, 60)
  }

  func testApplyCalculatorValues_StartsEditingIfNotAlready() {
    sut.offer = makeTestOffer(id: "test-offer-id")
    XCTAssertFalse(sut.isEditing)

    sut.applyCalculatorValues(amount: 30000, percentage: 60)

    XCTAssertTrue(sut.isEditing)
  }

  // MARK: - Test Helpers

  private func makeTestSchool(id: String, name: String) -> School {
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
      priorityTier: nil,
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
