import XCTest
@testable import TheRecruitingCompass

private final class MockEnricher: SchoolEnriching, @unchecked Sendable {
  var matches: [ScorecardMatch] = []
  var confirmInfo = AcademicInfo(sat25th: 1120, sat75th: 1330)
  var searchCalls = 0, confirmCalls = 0
  var searchError: Error?
  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch] {
    searchCalls += 1
    if let searchError { throw searchError }
    return matches
  }
  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo {
    confirmCalls += 1; return confirmInfo
  }
}

@MainActor
final class SchoolDetailAcademicFitTests: XCTestCase {
  nonisolated deinit {}

  private func match(_ id: Int) -> ScorecardMatch {
    ScorecardMatch(scorecardId: id, name: "U\(id)", city: nil, state: nil,
                   studentSize: nil, admissionRate: nil)
  }

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
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  /// Builds the VM the way the app does; injects the mock enricher and loads a school.
  private func makeVM(enricher: MockEnricher) async -> SchoolDetailViewModel {
    let mockSchoolsService = MockSchoolsService()
    mockSchoolsService.stubbedSchool = createMockSchool()

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

    let vm = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: MockAuthManager(),
      enrichService: enricher,
      cache: InMemoryCache()
    )
    await vm.loadSchool()
    return vm
  }

  override func tearDown() async throws {
    FamilyManager.shared.familyUnit = nil
  }

  func test_singleMatchAutoConfirmsAndPopulatesAcademicFit() async {
    let mock = MockEnricher(); mock.matches = [match(1)]
    let vm = await makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertEqual(mock.confirmCalls, 1)
    XCTAssertTrue(vm.enrichMatches.isEmpty)
    XCTAssertEqual(vm.school?.academicInfo?.sat25th, 1120)
    XCTAssertNotNil(vm.academicFit)
    XCTAssertTrue(vm.academicFit?.hasSchoolData ?? false)
  }

  func test_multipleMatchesShowsChooserWithoutConfirming() async {
    let mock = MockEnricher(); mock.matches = [match(1), match(2)]
    let vm = await makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertEqual(mock.confirmCalls, 0)
    XCTAssertEqual(vm.enrichMatches.count, 2)
  }

  func test_noMatchesSetsError() async {
    let mock = MockEnricher(); mock.matches = []
    let vm = await makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertNotNil(vm.enrichError)
    XCTAssertFalse(vm.isEnriching)
  }

  func test_forbiddenErrorShowsAthletesOnlyMessage() async {
    let mock = MockEnricher(); mock.searchError = SchoolEnrichmentError.forbidden
    let vm = await makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertEqual(vm.enrichError, "Only athlete accounts can look up academic data.")
    XCTAssertFalse(vm.isEnriching)
  }

  func test_loadPersonalFit_clearsBothFitsWhenSchoolIsNil() async {
    let mockSchoolsService = MockSchoolsService()
    let vm = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: MockAuthManager(),
      enrichService: MockEnricher(),
      cache: InMemoryCache()
    )
    // No loadSchool() call — vm.school stays nil.

    await vm.loadPersonalFit()

    XCTAssertNil(vm.personalFit)
    XCTAssertNil(vm.academicFit)
  }
}
