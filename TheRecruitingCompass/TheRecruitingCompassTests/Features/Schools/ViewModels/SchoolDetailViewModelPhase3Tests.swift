import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase3Tests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockFitScoreService: MockFitScoreService!
  var mockCollegeService: MockCollegeScorecardService!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockFitScoreService = MockFitScoreService()
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
      fitScoreService: mockFitScoreService,
      collegeService: mockCollegeService
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    mockSchoolsService = nil
    mockFitScoreService = nil
    mockCollegeService = nil
    FamilyManager.shared.familyUnit = nil
  }

  // MARK: - Fit Score Tests

  func testLoadFitScore_Success() async throws {
    // Given
    let expectedScore = FitScoreResult(
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
    mockFitScoreService.stubbedFitScore = expectedScore

    // When
    await viewModel.loadFitScore()

    // Then
    XCTAssertEqual(viewModel.fitScore?.score, 85.0)
    XCTAssertEqual(viewModel.fitScore?.tier, .safety)
    XCTAssertFalse(viewModel.isLoadingFitScore)
  }

  func testLoadFitScore_SetsLoadingState() async throws {
    // Given
    mockFitScoreService.stubbedFitScore = FitScoreResult(
      score: 75.0,
      tier: .match,
      breakdown: FitScoreBreakdown(
        athleticFit: 75,
        academicFit: 75,
        opportunityFit: 75,
        personalFit: 75
      ),
      missingDimensions: []
    )

    // When/Then - Loading should be true during execution
    // (We can't easily test this in Swift concurrency without more complex setup)
    await viewModel.loadFitScore()

    // Then - Loading should be false after completion
    XCTAssertFalse(viewModel.isLoadingFitScore)
  }

  func testLoadFitScore_WithDivisionRecommendation() async throws {
    // Given
    let lowScore = FitScoreResult(
      score: 45.0,
      tier: .unlikely,
      breakdown: FitScoreBreakdown(
        athleticFit: 40,
        academicFit: 45,
        opportunityFit: 48,
        personalFit: 47
      ),
      missingDimensions: []
    )
    let recommendation = DivisionRecommendation(
      shouldConsiderOtherDivisions: true,
      recommendedDivisions: ["D2", "D3"],
      message: "Based on your fit score, you may want to consider schools in D2, D3."
    )
    mockFitScoreService.stubbedFitScore = lowScore
    mockFitScoreService.stubbedRecommendation = recommendation
    mockSchoolsService.stubbedSchool = createMockSchool(division: "D1")

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNotNil(viewModel.fitScore)
    XCTAssertNotNil(viewModel.divisionRecommendation)
    XCTAssertEqual(viewModel.divisionRecommendation?.shouldConsiderOtherDivisions, true)
  }

  func testLoadFitScore_HandlesError() async throws {
    // Given
    mockFitScoreService.shouldThrowError = true

    // When
    await viewModel.loadFitScore()

    // Then - Should not crash, fitScore should remain nil
    XCTAssertNil(viewModel.fitScore)
    XCTAssertFalse(viewModel.isLoadingFitScore)
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

  // MARK: - Integration Tests

  func testLoadSchool_LoadsFitScoreAutomatically() async throws {
    // Given
    mockSchoolsService.stubbedSchool = createMockSchool()
    mockFitScoreService.stubbedFitScore = FitScoreResult(
      score: 80.0,
      tier: .safety,
      breakdown: FitScoreBreakdown(
        athleticFit: 80,
        academicFit: 80,
        opportunityFit: 80,
        personalFit: 80
      ),
      missingDimensions: []
    )

    // When
    await viewModel.loadSchool()

    // Then
    XCTAssertNotNil(viewModel.school)
    XCTAssertNotNil(viewModel.fitScore)
    XCTAssertEqual(viewModel.fitScore?.score, 80.0)
  }

  // MARK: - Helper

  private func createMockSchool(
    name: String = "Test School",
    division: String = "D1"
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
