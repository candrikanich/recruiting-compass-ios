import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPriorityTierTests: XCTestCase {

  var mockSchoolsService: MockSchoolsService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyManager: FamilyManager!
  var viewModel: SchoolDetailViewModel!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockAuthManager = MockAuthManager()
    mockFamilyManager = .shared
    viewModel = SchoolDetailViewModel(
      schoolId: "test-school-id",
      schoolsService: mockSchoolsService,
      authManager: mockAuthManager,
      familyManager: mockFamilyManager
    )
  }

  override func tearDown() async throws {
    mockSchoolsService = nil
    mockAuthManager = nil
    viewModel = nil
  }

  // MARK: - Update Priority Tier Tests

  func testUpdatePriorityTier_ToTierA_UpdatesSchool() async {
    // Given
    let initialSchool = createMockSchool(priorityTier: nil)
    let updatedSchool = createMockSchool(priorityTier: "A")
    mockSchoolsService.stubbedSchool = updatedSchool

    viewModel.school = initialSchool

    // When
    await viewModel.updatePriorityTier(.a)

    // Then
    XCTAssertEqual(viewModel.school?.priorityTier, "A")
    XCTAssertEqual(mockSchoolsService.updatePriorityTierCallCount, 1)
    XCTAssertEqual(mockSchoolsService.lastPriorityTier, .a)
  }

  func testUpdatePriorityTier_ToNil_UpdatesSchool() async {
    // Given
    let initialSchool = createMockSchool(priorityTier: "A")
    let updatedSchool = createMockSchool(priorityTier: nil)
    mockSchoolsService.stubbedSchool = updatedSchool

    viewModel.school = initialSchool

    // When
    await viewModel.updatePriorityTier(nil)

    // Then
    XCTAssertNil(viewModel.school?.priorityTier)
    XCTAssertEqual(mockSchoolsService.updatePriorityTierCallCount, 1)
    XCTAssertNil(mockSchoolsService.lastPriorityTier)
  }

  func testUpdatePriorityTier_SetsLoadingState() async {
    // Given
    let school = createMockSchool(priorityTier: nil)
    viewModel.school = school
    mockSchoolsService.stubbedSchool = school
    mockSchoolsService.delayDuration = 0.1

    // When
    let task = Task {
      await viewModel.updatePriorityTier(.a)
    }

    // Give the async task time to start
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

    // Then
    XCTAssertTrue(viewModel.isUpdatingPriorityTier)

    await task.value

    XCTAssertFalse(viewModel.isUpdatingPriorityTier)
  }

  func testUpdatePriorityTier_OnError_SetsErrorMessage() async {
    // Given
    let school = createMockSchool(priorityTier: nil)
    viewModel.school = school
    mockSchoolsService.shouldSucceed = false

    // When
    await viewModel.updatePriorityTier(.a)

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.errorMessage, "Failed to update priority tier")
  }

  func testUpdatePriorityTier_OnError_ClearsLoadingState() async {
    // Given
    let school = createMockSchool(priorityTier: nil)
    viewModel.school = school
    mockSchoolsService.shouldSucceed = false

    // When
    await viewModel.updatePriorityTier(.a)

    // Then
    XCTAssertFalse(viewModel.isUpdatingPriorityTier)
  }

  // MARK: - Helper Methods

  private func createMockSchool(priorityTier: String?) -> School {
    School(
      id: "test-school-id",
      userId: "test-user-id",
      name: "Test School",
      location: "Test Location",
      city: "Test City",
      state: "TS",
      division: "D1",
      conference: "Test Conference",
      ranking: 10,
      isFavorite: false,
      website: "test.edu",
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      priorityTier: priorityTier,
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
      familyUnitId: "test-family-id",
      createdBy: "test-user-id",
      createdAt: "2024-01-01T00:00:00Z",
      updatedBy: nil,
      updatedAt: nil
    )
  }
}
