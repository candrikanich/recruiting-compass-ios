import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase3Tests: XCTestCase {
  nonisolated deinit {}
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockCollegeService: MockCollegeScorecardService!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockCollegeService = MockCollegeScorecardService()

    // Set up FamilyManager.shared with test data
    FamilyManager.shared.familyUnit = FamilyUnit(
      id: "test-family-id",
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
      authManager: MockAuthManager(),
      collegeService: mockCollegeService,
      cache: InMemoryCache()
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    mockSchoolsService = nil
    mockCollegeService = nil
    FamilyManager.shared.familyUnit = nil
  }

  // MARK: - College Data Tests

  func testLookupCollegeData_Success() async throws {
    // Given
    let mockResult = CollegeDataResult(
      id: "1",
      name: "Test University",
      website: "test.edu",
      address: "123 Main St",
      city: "Testville",
      state: "CA",
      studentSize: 15000,
      carnegieSize: "L",
      admissionRate: 0.25,
      tuitionInState: 12000,
      tuitionOutOfState: 45000,
      latitude: 37.7749,
      longitude: -122.4194
    )
    mockCollegeService.stubbedResult = mockResult
    mockSchoolsService.stubbedSchool = createMockSchool(name: "Test University")
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertNil(viewModel.collegeDataError)
    XCTAssertFalse(viewModel.isLookingUpCollegeData)
  }

  func testLookupCollegeData_NotFound() async throws {
    // Given
    mockCollegeService.stubbedResult = nil
    mockSchoolsService.stubbedSchool = createMockSchool(name: "Unknown School")
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertEqual(viewModel.collegeDataError, "School not found in database")
    XCTAssertFalse(viewModel.isLookingUpCollegeData)
  }

  func testLookupCollegeData_APIError() async throws {
    // Given
    mockCollegeService.shouldThrowError = true
    mockCollegeService.errorToThrow = CollegeDataError.rateLimited
    mockSchoolsService.stubbedSchool = createMockSchool()
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertNotNil(viewModel.collegeDataError)
    XCTAssertFalse(viewModel.isLookingUpCollegeData)
  }

  func testLookupCollegeData_NetworkError() async throws {
    // Given
    let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    mockCollegeService.shouldThrowError = true
    mockCollegeService.errorToThrow = networkError
    mockSchoolsService.stubbedSchool = createMockSchool()
    await viewModel.loadSchool()

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertEqual(viewModel.collegeDataError, "Failed to lookup college data")
    XCTAssertFalse(viewModel.isLookingUpCollegeData)
  }

  func testLookupCollegeData_ClearsErrorOnNewLookup() async throws {
    // Given
    mockSchoolsService.stubbedSchool = createMockSchool()
    await viewModel.loadSchool()
    viewModel.collegeDataError = "Previous error"

    mockCollegeService.stubbedResult = CollegeDataResult(
      id: "1",
      name: "Test",
      website: nil,
      address: nil,
      city: nil,
      state: nil,
      studentSize: nil,
      carnegieSize: nil,
      admissionRate: nil,
      tuitionInState: nil,
      tuitionOutOfState: nil,
      latitude: nil,
      longitude: nil
    )

    // When
    await viewModel.lookupCollegeData()

    // Then
    XCTAssertNil(viewModel.collegeDataError)
  }

  // MARK: - Helper

  private func createMockSchool(
    name: String = "Test School",
    division: String = "D1",
    fitScore: Double? = nil,
    fitTier: String? = nil
  ) -> School {
    School(
      id: "school-1",
      userId: "user-1",
      name: name,
      location: "Test, CA",
      city: "Test",
      state: "CA",
      division: division,
      conference: "Test Conf",
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
      fitScore: fitScore,
      fitTier: fitTier,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }
}
