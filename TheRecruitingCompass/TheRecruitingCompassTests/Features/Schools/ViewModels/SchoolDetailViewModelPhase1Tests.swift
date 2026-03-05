import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase1Tests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyManager: FamilyManager!
  var mockFitScoreService: MockFitScoreService!
  var mockCoachesService: MockCoachesService!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockAuthManager = MockAuthManager()
    mockFamilyManager = FamilyManager.shared
    mockFitScoreService = MockFitScoreService()
    mockCoachesService = MockCoachesService()

    // Set up authenticated user
    mockAuthManager.user = User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil,
      dateOfBirth: nil
    )

    // Set up family unit
    mockFamilyManager.familyUnit = FamilyUnit(
      id: "family-1",
      createdByUserId: "user-1",
      familyName: "Test Family",
      familyCode: nil,
      codeGeneratedAt: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil,
      pendingPlayerDetails: nil
    )

    viewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: mockAuthManager,
      familyManager: mockFamilyManager,
      fitScoreService: mockFitScoreService,
      coachesService: mockCoachesService,
      cache: InMemoryCache()
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    mockSchoolsService = nil
    mockAuthManager = nil
    mockFamilyManager.familyUnit = nil
    mockFitScoreService = nil
    mockCoachesService = nil
  }

  // MARK: - Load School Tests

  func testLoadSchool_Success() async {
    // Given
    let mockSchool = createMockSchool()
    let mockHistory = [
      createMockStatusHistory(
        id: "history-1",
        previousStatus: "interested",
        newStatus: "contacted"
      )
    ]
    mockSchoolsService.stubbedSchool = mockSchool
    mockSchoolsService.stubbedStatusHistory = mockHistory

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNotNil(viewModel.school)
    XCTAssertEqual(viewModel.school?.id, "school-1")
    XCTAssertEqual(viewModel.school?.name, "Test University")
    XCTAssertEqual(viewModel.statusHistory.count, 1)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadSchool_SetsLoadingState() async {
    // Given
    mockSchoolsService.stubbedSchool = createMockSchool()
    mockSchoolsService.stubbedStatusHistory = []
    mockSchoolsService.delayDuration = 0.1

    // When
    let task = Task {
      await viewModel.loadSchool()
    }

    // Give async task time to start
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

    // Then - Should be loading during execution
    XCTAssertTrue(viewModel.isLoading)

    await task.value

    // Then - Should not be loading after completion
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadSchool_NoFamily_ShowsError() async {
    // Given
    mockFamilyManager.familyUnit = nil
    mockFamilyManager.currentMember = nil

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNil(viewModel.school)
    XCTAssertEqual(viewModel.errorMessage, "No active family")
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadSchool_Failure_ShowsError() async {
    // Given
    mockSchoolsService.shouldSucceed = false

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNil(viewModel.school)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load school") ?? false)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadSchool_LoadsStatusHistory() async {
    // Given
    let mockSchool = createMockSchool()
    let mockHistory = [
      createMockStatusHistory(
        id: "history-1",
        previousStatus: "interested",
        newStatus: "contacted"
      ),
      createMockStatusHistory(
        id: "history-2",
        previousStatus: "contacted",
        newStatus: "visited"
      )
    ]
    mockSchoolsService.stubbedSchool = mockSchool
    mockSchoolsService.stubbedStatusHistory = mockHistory

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertEqual(viewModel.statusHistory.count, 2, "statusHistory should have 2 items from mock")
    guard viewModel.statusHistory.count >= 2 else {
      XCTFail("statusHistory has only \(viewModel.statusHistory.count) items; check cache isolation or mock")
      return
    }
    XCTAssertEqual(viewModel.statusHistory[0].id, "history-1")
    XCTAssertEqual(viewModel.statusHistory[1].id, "history-2")
  }

  func testLoadSchool_LoadsFitScoreInParallel() async {
    // Given
    let mockSchool = createMockSchool()
    let mockFitScore = FitScoreResult(
      score: 85.0,
      tier: .safety,
      breakdown: FitScoreBreakdown(
        athleticFit: 90,
        academicFit: 85,
        opportunityFit: 80,
        personalFit: 85
      ),
      missingDimensions: []
    )
    mockSchoolsService.stubbedSchool = mockSchool
    mockSchoolsService.stubbedStatusHistory = []
    mockFitScoreService.stubbedFitScore = mockFitScore

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNotNil(viewModel.school)
    XCTAssertNotNil(viewModel.fitScore)
    XCTAssertEqual(viewModel.fitScore?.score, 85.0)
  }

  func testLoadSchool_LoadsCoachesInParallel() async {
    // Given
    let mockSchool = createMockSchool()
    let mockCoaches = [
      Coach(
        id: "coach-1",
        firstName: "John",
        lastName: "Smith",
        email: "john@school.edu",
        phone: "555-1234",
        position: "head",
        schoolId: "school-1",
        twitterHandle: nil,
        instagramHandle: nil,
        notes: nil,
        privateNotes: nil,
        responsivenessScore: 0.85,
        lastContactDate: nil,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
      )
    ]
    mockSchoolsService.stubbedSchool = mockSchool
    mockSchoolsService.stubbedStatusHistory = []
    mockCoachesService.mockCoaches = mockCoaches
    mockCoachesService.shouldSucceed = true

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNotNil(viewModel.school)
    XCTAssertEqual(viewModel.coaches.count, 1)
    XCTAssertEqual(viewModel.coaches.first?.id, "coach-1")
  }

  func testLoadSchool_ClearsErrorMessage() async {
    // Given
    viewModel.errorMessage = "Previous error"
    mockSchoolsService.stubbedSchool = createMockSchool()
    mockSchoolsService.stubbedStatusHistory = []

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNil(viewModel.errorMessage)
  }

  // MARK: - Update Status Tests

  func testUpdateStatus_Success() async {
    // Given
    let initialSchool = createMockSchool(status: "interested")
    let updatedSchool = createMockSchool(status: "contacted")
    let newHistory = [
      createMockStatusHistory(
        id: "history-1",
        previousStatus: "interested",
        newStatus: "contacted"
      )
    ]

    viewModel.school = initialSchool
    mockSchoolsService.stubbedSchool = updatedSchool
    mockSchoolsService.stubbedStatusHistory = newHistory

    // When
    await viewModel.updateStatus(to: .contacted)

    // Then
    XCTAssertEqual(viewModel.school?.status, "contacted")
    XCTAssertEqual(viewModel.statusHistory.count, 1)
    XCTAssertFalse(viewModel.isUpdatingStatus)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testUpdateStatus_SameStatus_NoOp() async {
    // Given
    let school = createMockSchool(status: "interested")
    viewModel.school = school
    let callCountBefore = mockSchoolsService.updateStatusCallCount

    // When
    await viewModel.updateStatus(to: .interested)

    // Then
    XCTAssertEqual(mockSchoolsService.updateStatusCallCount, callCountBefore)
    XCTAssertFalse(viewModel.isUpdatingStatus)
  }

  func testUpdateStatus_Failure_ShowsError() async {
    // Given
    let school = createMockSchool(status: "interested")
    viewModel.school = school
    mockSchoolsService.shouldSucceed = false

    // When
    await viewModel.updateStatus(to: .contacted)

    // Then
    XCTAssertEqual(viewModel.errorMessage, "Failed to update status")
    XCTAssertFalse(viewModel.isUpdatingStatus)
  }

  func testUpdateStatus_SetsLoadingState() async {
    // Given
    let school = createMockSchool(status: "interested")
    viewModel.school = school
    mockSchoolsService.stubbedSchool = school
    mockSchoolsService.stubbedStatusHistory = []
    mockSchoolsService.delayDuration = 0.1

    // When
    let task = Task {
      await viewModel.updateStatus(to: .contacted)
    }

    // Give async task time to start
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

    // Then
    XCTAssertTrue(viewModel.isUpdatingStatus)

    await task.value

    XCTAssertFalse(viewModel.isUpdatingStatus)
  }

  func testUpdateStatus_NoSchool_NoOp() async {
    // Given
    viewModel.school = nil

    // When
    await viewModel.updateStatus(to: .contacted)

    // Then
    XCTAssertEqual(mockSchoolsService.updateStatusCallCount, 0)
  }

  // MARK: - Toggle Favorite Tests

  func testToggleFavorite_OptimisticUpdate() async {
    // Given
    let school = createMockSchool(isFavorite: false)
    viewModel.school = school
    mockSchoolsService.shouldSucceed = true

    // When
    await viewModel.toggleFavorite()

    // Then
    XCTAssertTrue(viewModel.school?.isFavorite ?? false)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testToggleFavorite_TogglesFromTrueToFalse() async {
    // Given
    let school = createMockSchool(isFavorite: true)
    viewModel.school = school
    mockSchoolsService.shouldSucceed = true

    // When
    await viewModel.toggleFavorite()

    // Then
    XCTAssertFalse(viewModel.school?.isFavorite ?? true)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testToggleFavorite_RevertOnError() async {
    // Given
    let school = createMockSchool(isFavorite: false)
    viewModel.school = school
    mockSchoolsService.shouldThrowError = true

    // When
    await viewModel.toggleFavorite()

    // Then - Should revert to original state
    XCTAssertFalse(viewModel.school?.isFavorite ?? true)
    XCTAssertEqual(viewModel.errorMessage, "Failed to update favorite")
  }

  func testToggleFavorite_NoSchool_NoOp() async {
    // Given
    viewModel.school = nil

    // When
    await viewModel.toggleFavorite()

    // Then
    XCTAssertEqual(mockSchoolsService.toggleFavoriteCallCount, 0)
  }

  // MARK: - Helper Methods

  private func createMockSchool(
    status: String = "interested",
    isFavorite: Bool = false
  ) -> School {
    School(
      id: "school-1",
      userId: "user-1",
      name: "Test University",
      location: "Test City, TS",
      city: "Test City",
      state: "TS",
      division: "D1",
      conference: "Test Conference",
      ranking: 10,
      isFavorite: isFavorite,
      website: "test.edu",
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: status,
      statusChangedAt: "2025-01-01T00:00:00Z",
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
      familyUnitId: "family-1",
      createdBy: "user-1",
      updatedBy: "user-1",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }

  private func createMockStatusHistory(
    id: String,
    previousStatus: String?,
    newStatus: String
  ) -> SchoolStatusHistory {
    let dateFormatter = ISO8601DateFormatter()
    let date = dateFormatter.date(from: "2025-01-15T10:00:00Z") ?? Date()

    return SchoolStatusHistory(
      id: id,
      schoolId: "school-1",
      previousStatus: previousStatus,
      newStatus: newStatus,
      changedBy: "user-1",
      changedAt: date,
      notes: nil,
      createdAt: date
    )
  }
}
