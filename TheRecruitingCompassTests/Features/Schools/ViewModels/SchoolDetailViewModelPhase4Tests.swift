import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase4Tests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockCoachesService: MockCoachesService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyManager: FamilyManager!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockCoachesService = MockCoachesService()
    mockAuthManager = MockAuthManager()
    mockFamilyManager = FamilyManager.shared

    mockAuthManager.mockUser = User(
      id: "user-1",
      email: "test@example.com",
      fullName: "Test User",
      role: "player",
      familyUnitId: "family-1"
    )
    mockFamilyManager.familyUnitId = "family-1"

    viewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: mockAuthManager,
      familyManager: mockFamilyManager,
      coachesService: mockCoachesService
    )
  }

  override func tearDown() {
    viewModel = nil
    mockSchoolsService = nil
    mockCoachesService = nil
    mockAuthManager = nil
    mockFamilyManager = nil
  }

  // MARK: - Coaches Loading Tests

  func testLoadCoaches_Success() async {
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
    mockCoachesService.mockCoaches = mockCoaches
    mockCoachesService.shouldSucceed = true

    await viewModel.loadCoaches()

    XCTAssertEqual(viewModel.coaches.count, 1)
    XCTAssertEqual(viewModel.coaches.first?.id, "coach-1")
    XCTAssertFalse(viewModel.isLoadingCoaches)
  }

  func testLoadCoaches_EmptyList() async {
    mockCoachesService.mockCoaches = []
    mockCoachesService.shouldSucceed = true

    await viewModel.loadCoaches()

    XCTAssertTrue(viewModel.coaches.isEmpty)
    XCTAssertFalse(viewModel.isLoadingCoaches)
  }

  func testLoadCoaches_Failure() async {
    mockCoachesService.shouldSucceed = false

    await viewModel.loadCoaches()

    // Non-critical failure - should not crash, just show empty state
    XCTAssertTrue(viewModel.coaches.isEmpty)
    XCTAssertFalse(viewModel.isLoadingCoaches)
    XCTAssertNil(viewModel.errorMessage) // Non-critical, no error shown to user
  }

  // MARK: - Coaching Philosophy Tests

  func testStartEditingCoachingPhilosophy() {
    let mockSchool = createMockSchool(
      coachingPhilosophy: "Test Philosophy",
      coachingStyle: "Test Style"
    )
    viewModel.school = mockSchool

    viewModel.startEditingCoachingPhilosophy()

    XCTAssertTrue(viewModel.isEditingCoachingPhilosophy)
    XCTAssertEqual(viewModel.editedCoachingPhilosophy.coachingPhilosophy, "Test Philosophy")
    XCTAssertEqual(viewModel.editedCoachingPhilosophy.coachingStyle, "Test Style")
  }

  func testCancelEditingCoachingPhilosophy() {
    viewModel.isEditingCoachingPhilosophy = true
    viewModel.editedCoachingPhilosophy = EditableCoachingPhilosophy(
      coachingPhilosophy: "Test"
    )

    viewModel.cancelEditingCoachingPhilosophy()

    XCTAssertFalse(viewModel.isEditingCoachingPhilosophy)
    XCTAssertTrue(viewModel.editedCoachingPhilosophy.coachingPhilosophy.isEmpty)
  }

  func testSaveCoachingPhilosophy_Success() async {
    viewModel.editedCoachingPhilosophy = EditableCoachingPhilosophy(
      coachingPhilosophy: "New Philosophy",
      coachingStyle: "New Style",
      recruitingApproach: "New Approach",
      communicationStyle: "New Communication",
      successMetrics: "New Metrics"
    )
    mockSchoolsService.shouldSucceed = true

    await viewModel.saveCoachingPhilosophy()

    XCTAssertFalse(viewModel.isEditingCoachingPhilosophy)
    XCTAssertFalse(viewModel.isSavingCoachingPhilosophy)
    XCTAssertNotNil(viewModel.school)
  }

  func testSaveCoachingPhilosophy_EmptyFields() async {
    viewModel.editedCoachingPhilosophy = EditableCoachingPhilosophy(
      coachingPhilosophy: "",
      coachingStyle: "Only Style Set",
      recruitingApproach: "",
      communicationStyle: "",
      successMetrics: ""
    )
    mockSchoolsService.shouldSucceed = true

    await viewModel.saveCoachingPhilosophy()

    // Should handle empty strings (convert to nil in service)
    XCTAssertFalse(viewModel.isEditingCoachingPhilosophy)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveCoachingPhilosophy_Failure() async {
    viewModel.editedCoachingPhilosophy = EditableCoachingPhilosophy(
      coachingPhilosophy: "Test"
    )
    mockSchoolsService.shouldSucceed = false

    await viewModel.saveCoachingPhilosophy()

    XCTAssertTrue(viewModel.isEditingCoachingPhilosophy) // Sheet stays open on error
    XCTAssertFalse(viewModel.isSavingCoachingPhilosophy)
    XCTAssertEqual(viewModel.errorMessage, "Failed to save coaching philosophy")
  }

  // MARK: - Delete Tests

  func testConfirmDelete() {
    viewModel.confirmDelete()

    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  func testDeleteSchool_SimpleSuccess() async {
    var onSuccessCalled = false
    mockSchoolsService.shouldSucceed = true

    await viewModel.deleteSchool {
      onSuccessCalled = true
    }

    XCTAssertTrue(onSuccessCalled)
    XCTAssertFalse(viewModel.isDeleting)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.deleteErrorMessage)
  }

  func testDeleteSchool_CascadeFallback() async {
    var onSuccessCalled = false
    mockSchoolsService.simpleDeleteShouldFail = true // First attempt fails
    mockSchoolsService.shouldSucceed = true // Cascade succeeds

    await viewModel.deleteSchool {
      onSuccessCalled = true
    }

    XCTAssertTrue(onSuccessCalled)
    XCTAssertFalse(viewModel.isDeleting)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.deleteErrorMessage)
  }

  func testDeleteSchool_Failure() async {
    var onSuccessCalled = false
    mockSchoolsService.shouldSucceed = false

    await viewModel.deleteSchool {
      onSuccessCalled = true
    }

    XCTAssertFalse(onSuccessCalled)
    XCTAssertFalse(viewModel.isDeleting)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertEqual(viewModel.deleteErrorMessage, "Failed to delete school. Please try again.")
  }

  // MARK: - Helper Methods

  private func createMockSchool(
    coachingPhilosophy: String? = nil,
    coachingStyle: String? = nil
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
      ranking: nil,
      isFavorite: false,
      website: "test.edu",
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      priorityTier: nil,
      notes: nil,
      privateNotes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
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
}
