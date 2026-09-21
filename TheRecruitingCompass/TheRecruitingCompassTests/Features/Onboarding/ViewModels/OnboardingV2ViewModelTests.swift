import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("OnboardingV2ViewModel — validation and derived state")
@MainActor
struct OnboardingV2ViewModelTests {

  private func makeSUT(
    onboardingService: (any OnboardingManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: MockAuthManager? = nil,
    schoolsRepository: SpySchoolsRepository? = nil,
    familyService: StubFamilyService? = nil,
    ncaaDatabase: StubNcaaDatabase? = nil,
    collegeScorecardService: StubCollegeScorecardService? = nil,
    faviconService: SpyFaviconService? = nil
  ) -> OnboardingV2ViewModel {
    OnboardingV2ViewModel(
      onboardingService: onboardingService ?? MockOnboardingService(),
      preferenceService: preferenceService ?? StubPreferenceService(),
      authManager: authManager ?? MockAuthManager(),
      schoolsRepository: schoolsRepository ?? SpySchoolsRepository(),
      recommendationService: StubRecommendationService(),
      familyService: familyService ?? StubFamilyService(),
      ncaaDatabase: ncaaDatabase ?? StubNcaaDatabase(),
      collegeScorecardService: collegeScorecardService ?? StubCollegeScorecardService(),
      faviconService: faviconService ?? SpyFaviconService()
    )
  }

  // MARK: - isStep1Valid

  @Test func step1InvalidWhenEmpty() {
    let vm = makeSUT()
    #expect(!vm.isStep1Valid)
  }

  @Test func step1InvalidWhenSportOnlySet() {
    let vm = makeSUT()
    vm.primarySport = "Baseball"
    #expect(!vm.isStep1Valid)
  }

  @Test func step1InvalidWhenGradYearOnlySet() {
    let vm = makeSUT()
    vm.graduationYear = 2028
    #expect(!vm.isStep1Valid)
  }

  @Test func step1ValidWhenSportAndGradYearSet() {
    let vm = makeSUT()
    vm.primarySport = "Baseball"
    vm.graduationYear = 2028
    #expect(vm.isStep1Valid)
  }

  @Test func step1InvalidWhenSportIsWhitespaceOnly() {
    let vm = makeSUT()
    vm.primarySport = "   "
    vm.graduationYear = 2028
    #expect(!vm.isStep1Valid)
  }

  @Test func step1ValidRegardlessOfZipCode() {
    let vm = makeSUT()
    vm.primarySport = "Soccer"
    vm.graduationYear = 2027
    vm.zipCode = ""
    #expect(vm.isStep1Valid)
    vm.zipCode = "12345"
    #expect(vm.isStep1Valid)
  }

  // MARK: - completeOnboarding

  // Regression: completeOnboarding must not stamp a hardcoded "freshman" phase — it should
  // reflect the athlete's actual grade, derived from the graduation year they entered.
  @Test func completeOnboarding_startingPhase_isGradeDerivedNotHardcoded() async {
    let mockOnboardingService = MockOnboardingService()
    let authManager = MockAuthManager()
    authManager.setMockUser(User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    ))
    let vm = makeSUT(onboardingService: mockOnboardingService, authManager: authManager)
    vm.graduationYear = 2028

    _ = await vm.completeOnboarding()

    let expectedPhase = GradeLevelHelper.phase(forGrade: GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028))
    #expect(mockOnboardingService.lastStartingPhase == expectedPhase)
  }

  // MARK: - zipCodeError

  @Test func zipCodeErrorNilWhenEmpty() {
    let vm = makeSUT()
    vm.zipCode = ""
    #expect(vm.zipCodeError == nil)
  }

  @Test func zipCodeErrorNilForValid5Digits() {
    let vm = makeSUT()
    vm.zipCode = "60614"
    #expect(vm.zipCodeError == nil)
  }

  @Test func zipCodeErrorForTooShort() {
    let vm = makeSUT()
    vm.zipCode = "123"
    #expect(vm.zipCodeError != nil)
  }

  @Test func zipCodeErrorForTooLong() {
    let vm = makeSUT()
    vm.zipCode = "123456"
    #expect(vm.zipCodeError != nil)
  }

  @Test func zipCodeErrorForNonNumeric() {
    let vm = makeSUT()
    vm.zipCode = "abcde"
    #expect(vm.zipCodeError != nil)
  }

  @Test func zipCodeErrorForMixed() {
    let vm = makeSUT()
    vm.zipCode = "123ab"
    #expect(vm.zipCodeError != nil)
  }

  @Test func zipCodeWhitespaceOnlyTreatedAsEmpty() {
    let vm = makeSUT()
    vm.zipCode = "   "
    #expect(vm.zipCodeError == nil)
  }

  // MARK: - derivedGender

  @Test func derivedGenderMaleForBaseball() {
    let vm = makeSUT()
    vm.primarySport = "Baseball"
    #expect(vm.derivedGender == Gender.male.rawValue)
  }

  @Test func derivedGenderFemaleForSoftball() {
    let vm = makeSUT()
    vm.primarySport = "Softball"
    #expect(vm.derivedGender == Gender.female.rawValue)
  }

  @Test func derivedGenderNilForSoccer() {
    let vm = makeSUT()
    vm.primarySport = "Soccer"
    #expect(vm.derivedGender == nil)
  }

  @Test func derivedGenderNilWhenEmpty() {
    let vm = makeSUT()
    vm.primarySport = ""
    #expect(vm.derivedGender == nil)
  }

  // MARK: - filteredSports

  @Test func filteredSportsReturnsAllWhenSearchEmpty() {
    let vm = makeSUT()
    vm.sportSearchText = ""
    #expect(vm.filteredSports == OnboardingConstants.commonSports)
  }

  @Test func filteredSportsFiltersOnSearch() {
    let vm = makeSUT()
    vm.sportSearchText = "base"
    #expect(vm.filteredSports.contains("Baseball"))
    #expect(!vm.filteredSports.contains("Soccer"))
  }

  @Test func filteredSportsCaseInsensitive() {
    let vm = makeSUT()
    vm.sportSearchText = "SOCCER"
    #expect(vm.filteredSports.contains("Soccer"))
  }

  @Test func filteredSportsWhitespaceOnlyShowsAll() {
    let vm = makeSUT()
    vm.sportSearchText = "   "
    #expect(vm.filteredSports == OnboardingConstants.commonSports)
  }

  // MARK: - graduationYearDisplay

  @Test func graduationYearDisplayEmptyWhenNil() {
    let vm = makeSUT()
    #expect(vm.graduationYearDisplay == "")
  }

  @Test func graduationYearDisplayShowsYear() {
    let vm = makeSUT()
    vm.graduationYear = 2028
    #expect(vm.graduationYearDisplay == "2028")
  }

  @Test func settingGraduationYearDisplayParsesInt() {
    let vm = makeSUT()
    vm.graduationYearDisplay = "2027"
    #expect(vm.graduationYear == 2027)
  }

  @Test func settingGraduationYearDisplayToNonNumberSetsNil() {
    let vm = makeSUT()
    vm.graduationYear = 2028
    vm.graduationYearDisplay = "abc"
    #expect(vm.graduationYear == nil)
  }

  // MARK: - loadExistingData

  // Regression for the onboarding 1-step collapse: the container decides whether to show
  // "Tell us about you" at all based on isStep1Valid AFTER loadExistingData() runs — a
  // player whose sport/grad-year were already flushed from signup-time metadata (see
  // AccountProvisioningService) must resolve to valid here, or the container would show
  // the redundant step to everyone regardless of what was captured at signup.
  @Test func loadExistingDataPrefillsFromCanonicalPreferencesMakingStep1Valid() async {
    let mockPrefService = StubPreferenceService()
    mockPrefService.storedPlayerDetails = {
      var details = PlayerDetails.default
      details.primarySport = "Baseball"
      details.graduationYear = 2028
      return details
    }()
    let vm = makeSUT(preferenceService: mockPrefService)
    #expect(!vm.isStep1Valid)

    await vm.loadExistingData()

    #expect(vm.isStep1Valid)
    #expect(vm.primarySport == "Baseball")
    #expect(vm.graduationYear == 2028)
  }

  @Test func loadExistingDataLeavesStep1InvalidWhenNothingStored() async {
    let vm = makeSUT()

    let succeeded = await vm.loadExistingData()

    #expect(!vm.isStep1Valid)
    #expect(succeeded, "No stored data is a successful fetch that found nothing — not a failure")
  }

  // Regression: a transient fetch failure must not read the same as "nothing stored" to
  // the caller. The onboarding container relies on this to avoid routing a player who
  // already has canonical sport/grad-year through the redundant Step 1 (or worse, letting
  // them overwrite it) just because one read happened to fail.
  @Test func loadExistingDataReturnsFalseWhenPlayerFetchFails() async {
    let mockPrefService = StubPreferenceService()
    mockPrefService.errorToThrow = NSError(domain: "test", code: 500)
    let vm = makeSUT(preferenceService: mockPrefService)

    let succeeded = await vm.loadExistingData()

    #expect(!succeeded)
  }

  @Test func loadExistingDataDoesNotOverwriteAlreadyEnteredValues() async {
    let mockPrefService = StubPreferenceService()
    mockPrefService.storedPlayerDetails = {
      var details = PlayerDetails.default
      details.primarySport = "Soccer"
      details.graduationYear = 2030
      return details
    }()
    let vm = makeSUT(preferenceService: mockPrefService)
    vm.primarySport = "Baseball"
    vm.graduationYear = 2028

    await vm.loadExistingData()

    #expect(vm.primarySport == "Baseball")
    #expect(vm.graduationYear == 2028)
  }

  // MARK: - saveStep1

  @Test func saveStep1ReturnsFalseWhenInvalid() async {
    let vm = makeSUT()
    let result = await vm.saveStep1()
    #expect(!result)
  }

  @Test func saveStep1ReturnsFalseWithInvalidZip() async {
    let vm = makeSUT()
    vm.primarySport = "Baseball"
    vm.graduationYear = 2028
    vm.zipCode = "abc"
    let result = await vm.saveStep1()
    #expect(!result)
  }

  @Test func saveStep1SucceedsWithValidData() async {
    let mockPrefService = StubPreferenceService()
    let vm = makeSUT(preferenceService: mockPrefService)
    vm.primarySport = "Baseball"
    vm.graduationYear = 2028
    vm.zipCode = "60614"

    let result = await vm.saveStep1()
    #expect(result)
    #expect(vm.errorMessage == nil)
    #expect(mockPrefService.saveCallCount >= 1)
  }

  @Test func saveStep1SucceedsWithoutZip() async {
    let mockPrefService = StubPreferenceService()
    let vm = makeSUT(preferenceService: mockPrefService)
    vm.primarySport = "Soccer"
    vm.graduationYear = 2027

    let result = await vm.saveStep1()
    #expect(result)
    #expect(mockPrefService.saveCallCount == 1)
  }

  @Test func saveStep1SetsErrorOnFailure() async {
    let mockPrefService = StubPreferenceService()
    mockPrefService.errorToThrow = NSError(domain: "test", code: 500)
    let vm = makeSUT(preferenceService: mockPrefService)
    vm.primarySport = "Baseball"
    vm.graduationYear = 2028

    let result = await vm.saveStep1()
    #expect(!result)
    #expect(vm.errorMessage != nil)
  }

  // MARK: - clearError

  @Test func clearErrorResetsMessage() {
    let vm = makeSUT()
    vm.errorMessage = "Something went wrong"
    vm.clearError()
    #expect(vm.errorMessage == nil)
  }
}

// MARK: - Minimal stubs for non-tested dependencies

private final class StubPreferenceService: PreferenceManaging, @unchecked Sendable {
  var errorToThrow: Error?
  var storedPlayerDetails: PlayerDetails?
  private(set) var saveCallCount = 0

  func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? {
    if let errorToThrow { throw errorToThrow }
    if category == .player, let storedPlayerDetails {
      return storedPlayerDetails as? T
    }
    return nil
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T {
    saveCallCount += 1
    if let errorToThrow { throw errorToThrow }
    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {}
}

private final class SpySchoolsRepository: SchoolsRepository, @unchecked Sendable {
  private static let placeholder = School.mock(id: "stub", name: "Stub U")

  private(set) var lastCreateRequest: SchoolCreateRequest?

  func createSchool(request: SchoolCreateRequest) async throws -> School {
    lastCreateRequest = request
    return Self.placeholder
  }
  func fetchSchools(familyUnitId: String) async throws -> [School] { [] }
  func fetchSchool(id: String, familyUnitId: String) async throws -> School { Self.placeholder }
  func deleteSchool(id: String) async throws {}
  func cascadeDeleteSchool(id: String) async throws -> DeleteResult {
    DeleteResult(isCascadeUsed: false, deletedInteractions: 0, deletedNotes: 0)
  }
  func toggleFavorite(id: String, isFavorite: Bool) async throws {}
  func updateStatus(id: String, newStatus: SchoolStatus, previousStatus: SchoolStatus, userId: String) async throws -> School { Self.placeholder }
  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory] { [] }
  func reactivateSchool(id: String, familyUnitId: String, userId: String) async throws -> School { Self.placeholder }
  func updateNotes(id: String, notes: String) async throws -> School { Self.placeholder }
  func fetchOutreachNotes(id: String) async throws -> SchoolOutreachNotes { SchoolOutreachNotes(whyProgram: nil, fitReason: nil) }
  func updateOutreachNotes(id: String, whyProgram: String?, fitReason: String?) async throws {}
  func updateQuestionnaireCompleted(id: String, completed: Bool) async throws {}
  func addPro(id: String, familyUnitId: String, text: String) async throws -> School { Self.placeholder }
  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School { Self.placeholder }
  func addCon(id: String, familyUnitId: String, text: String) async throws -> School { Self.placeholder }
  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School { Self.placeholder }
  func updateBasicInfo(id: String, info: EditableBasicInfo, existingAcademicInfo: AcademicInfo?) async throws -> School { Self.placeholder }
  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School { Self.placeholder }
  func updateCoachingPhilosophy(id: String, philosophy: EditableCoachingPhilosophy) async throws -> School { Self.placeholder }
}

private final class StubRecommendationService: SchoolRecommendationManaging, @unchecked Sendable {
  func fetchRecommendations(athleteId: String, limit: Int) async throws -> [SchoolRecommendation] { [] }
  func dismissRecommendation(catalogKey: String, athleteId: String) async throws {}
}

private final class StubFamilyService: FamilyManaging, @unchecked Sendable {
  var stubbedFamilyUnit: FamilyUnit? = FamilyUnit(
    id: "family-1",
    createdByUserId: "user-1",
    familyName: nil,
    familyCode: nil,
    codeGeneratedAt: nil,
    createdAt: nil,
    updatedAt: nil,
    homeLatitude: nil,
    homeLongitude: nil
  )

  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? { stubbedFamilyUnit }
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] { [] }
  func getCurrentMember(userId: String) async throws -> FamilyMember? { nil }
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse {
    fatalError("Not used in onboarding v2 tests")
  }
  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    fatalError("Not used in onboarding v2 tests")
  }
  func removeFamilyMember(memberId: String) async throws {}
  func joinFamilyWithCode(familyCode: String) async throws {}
  func getParentFamilies() async throws -> [ParentFamilyData] { [] }
  func sendEmailInvite(email: String, role: String, pendingPlayerDetails: PendingPlayerDetails?) async throws {}
  func fetchPendingInvitations() async throws -> [FamilyInvitation] { [] }
  func revokeInvitation(id: String) async throws {}
  func resendInvitation(id: String, email: String, role: String) async throws {}
  func lookupInviteByToken(_ token: String) async throws -> InviteDetails {
    fatalError("Not used in onboarding v2 tests")
  }
  func acceptInvite(token: String) async throws -> AcceptInviteResponse {
    AcceptInviteResponse(success: true, familyUnitId: "family-1", onboardingComplete: true, prefill: nil)
  }
  func declineInvite(token: String) async throws {}
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws {}
}

private final class StubNcaaDatabase: NcaaDatabaseManaging, @unchecked Sendable {
  var stubbedResult: NcaaLookupResult?
  private(set) var lookupCallCount = 0

  func lookup(schoolName: String) async -> NcaaLookupResult? {
    lookupCallCount += 1
    return stubbedResult
  }
}

private final class StubCollegeScorecardService: CollegeScorecardManaging, @unchecked Sendable {
  var stubbedResult: CollegeDataResult?
  private(set) var lookupCallCount = 0

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    lookupCallCount += 1
    return stubbedResult
  }
  func lookupCollege(id: String) async throws -> CollegeDataResult? { stubbedResult }
  func searchColleges(query: String) async throws -> [CollegeSearchResult] { [] }
}

// Fire-and-forget in production (see addSchool), so tests that need to observe the call
// must await it explicitly rather than checking the count right after addSchool returns.
private actor SpyFaviconService: SchoolFaviconManaging {
  private(set) var fetchAndPersistCallCount = 0
  private(set) var lastSchool: School?
  private var continuation: CheckedContinuation<Void, Never>?

  func fetchAndPersist(school: School) async {
    fetchAndPersistCallCount += 1
    lastSchool = school
    continuation?.resume()
    continuation = nil
  }

  func waitForCall() async {
    if fetchAndPersistCallCount > 0 { return }
    await withCheckedContinuation { continuation = $0 }
  }
}

// MARK: - addSchool enrichment parity with Schools-page "Add School" flow

@Suite("OnboardingV2ViewModel — addSchool enrichment")
@MainActor
struct OnboardingV2ViewModelAddSchoolTests {

  private func makeSUT(
    schoolsRepository: SpySchoolsRepository = SpySchoolsRepository(),
    ncaaDatabase: StubNcaaDatabase = StubNcaaDatabase(),
    collegeScorecardService: any CollegeScorecardManaging = StubCollegeScorecardService(),
    faviconService: any SchoolFaviconManaging = SpyFaviconService(),
    authManager: MockAuthManager? = nil
  ) -> OnboardingV2ViewModel {
    let auth = authManager ?? MockAuthManager()
    if auth.user == nil {
      auth.setMockUser(User(
        id: "user-1",
        email: "test@example.com",
        emailConfirmedAt: nil,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
        role: .player
      ))
    }
    return OnboardingV2ViewModel(
      onboardingService: MockOnboardingService(),
      preferenceService: StubPreferenceService(),
      authManager: auth,
      schoolsRepository: schoolsRepository,
      recommendationService: StubRecommendationService(),
      familyService: StubFamilyService(),
      ncaaDatabase: ncaaDatabase,
      collegeScorecardService: collegeScorecardService,
      faviconService: faviconService
    )
  }

  private func makeRecommendation(
    division: String? = "D1",
    conference: String? = "Mid-American Conference",
    website: String? = nil
  ) -> SchoolRecommendation {
    SchoolRecommendation(
      catalogKey: "bgsu",
      name: "Bowling Green State University",
      division: division,
      conference: conference,
      state: "OH",
      website: website,
      athleticsUrl: nil,
      score: 1.0,
      reasons: []
    )
  }

  // Regression for the onboarding-added-school data gap: schools added from Step 2 must run
  // the same College Scorecard enrichment + favicon fetch the Schools-page AddSchoolViewModel
  // runs, or they save with null location/website/academic info (see screenshot in the bug report).
  @Test func addSchoolEnrichesRequestWithScorecardData() async {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedResult = CollegeDataResult(
      id: "123",
      name: "Bowling Green State University",
      website: "www.bgsu.edu",
      address: "123 Campus Dr",
      city: "Bowling Green",
      state: "OH",
      studentSize: 14000,
      carnegieSize: nil,
      enrollmentAll: nil,
      admissionRate: nil,
      studentFacultyRatio: nil,
      tuitionInState: nil,
      tuitionOutOfState: nil,
      avgNetPrice: nil,
      graduationRate: nil,
      latitude: 41.3,
      longitude: -83.6
    )
    let repo = SpySchoolsRepository()
    let vm = makeSUT(schoolsRepository: repo, collegeScorecardService: scorecard)

    let result = await vm.addSchool(makeRecommendation())

    #expect(result)
    #expect(scorecard.lookupCallCount == 1)
    let request = repo.lastCreateRequest
    #expect(request?.academicInfo?.address == "123 Campus Dr")
    #expect(request?.academicInfo?.latitude == 41.3)
    #expect(request?.website == "www.bgsu.edu")
    // Top-level city/location must also be populated — schools-list and city-based
    // search read these fields directly, not academicInfo (Qodo review finding #2).
    #expect(request?.city == "Bowling Green")
    #expect(request?.location == "Bowling Green, OH")
  }

  @Test func addSchoolFetchesAndPersistsFavicon() async {
    let favicon = SpyFaviconService()
    let vm = makeSUT(faviconService: favicon)

    _ = await vm.addSchool(makeRecommendation())
    await favicon.waitForCall()

    let count = await favicon.fetchAndPersistCallCount
    #expect(count == 1)
  }

  // Recommendation already carries division/conference (from the recommendation engine) —
  // must not be silently overwritten by a redundant NCAA lookup.
  @Test func addSchoolKeepsRecommendationDivisionAndConferenceWithoutNcaaLookup() async {
    let ncaa = StubNcaaDatabase()
    let repo = SpySchoolsRepository()
    let vm = makeSUT(schoolsRepository: repo, ncaaDatabase: ncaa)

    _ = await vm.addSchool(makeRecommendation(division: "D1", conference: "Mid-American Conference"))

    #expect(ncaa.lookupCallCount == 0)
    #expect(repo.lastCreateRequest?.division == "D1")
    #expect(repo.lastCreateRequest?.conference == "Mid-American Conference")
  }

  @Test func addSchoolFallsBackToNcaaLookupWhenRecommendationMissingDivision() async {
    let ncaa = StubNcaaDatabase()
    ncaa.stubbedResult = NcaaLookupResult(division: .d1, conference: "Mid-American Conference")
    let repo = SpySchoolsRepository()
    let vm = makeSUT(schoolsRepository: repo, ncaaDatabase: ncaa)

    _ = await vm.addSchool(makeRecommendation(division: nil, conference: nil))

    #expect(ncaa.lookupCallCount == 1)
    #expect(repo.lastCreateRequest?.division == "D1")
    #expect(repo.lastCreateRequest?.conference == "Mid-American Conference")
  }

  @Test func addSchoolSucceedsWhenEnrichmentLookupsFail() async {
    // Enrichment is best-effort: a College Scorecard failure must not block school creation.
    let scorecard = FailingCollegeScorecardService()
    let repo = SpySchoolsRepository()
    let vm = makeSUT(schoolsRepository: repo, collegeScorecardService: scorecard)

    let result = await vm.addSchool(makeRecommendation())

    #expect(result)
    #expect(repo.lastCreateRequest != nil)
  }

  // Regression: favicon persistence must not block the recommendation being removed /
  // the Add button re-enabling — a slow favicon fetch previously left the same
  // recommendation submittable again, risking a duplicate createSchool call (Qodo finding #4).
  @Test func addSchoolDoesNotWaitOnFaviconBeforeRemovingRecommendation() async {
    let vm = makeSUT(faviconService: HangingFaviconService())
    let recommendation = makeRecommendation()
    vm.recommendations = [recommendation]

    let result = await vm.addSchool(recommendation)

    #expect(result)
    #expect(vm.recommendations.isEmpty)
    #expect(vm.schoolsAdded == 1)
  }
}

/// Never resumes — proves addSchool doesn't await favicon persistence before completing.
private actor HangingFaviconService: SchoolFaviconManaging {
  func fetchAndPersist(school: School) async {
    await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
  }
}

private final class FailingCollegeScorecardService: CollegeScorecardManaging, @unchecked Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult? { throw CollegeDataError.schoolNotFound }
  func lookupCollege(id: String) async throws -> CollegeDataResult? { throw CollegeDataError.schoolNotFound }
  func searchColleges(query: String) async throws -> [CollegeSearchResult] { [] }
}
