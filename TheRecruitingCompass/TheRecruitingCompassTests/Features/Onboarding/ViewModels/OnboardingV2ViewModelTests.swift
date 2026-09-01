import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("OnboardingV2ViewModel — validation and derived state")
@MainActor
struct OnboardingV2ViewModelTests {

  private func makeSUT(
    onboardingService: (any OnboardingManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: MockAuthManager? = nil
  ) -> OnboardingV2ViewModel {
    OnboardingV2ViewModel(
      onboardingService: onboardingService ?? MockOnboardingService(),
      preferenceService: preferenceService ?? StubPreferenceService(),
      authManager: authManager ?? MockAuthManager(),
      schoolsRepository: StubSchoolsRepository(),
      recommendationService: StubRecommendationService(),
      familyService: StubFamilyService()
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
  private(set) var saveCallCount = 0

  func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? {
    if let errorToThrow { throw errorToThrow }
    return nil
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T {
    saveCallCount += 1
    if let errorToThrow { throw errorToThrow }
    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {}
}

private final class StubSchoolsRepository: SchoolsRepository, @unchecked Sendable {
  private static let placeholder = School.mock(id: "stub", name: "Stub U")

  func createSchool(request: SchoolCreateRequest) async throws -> School { Self.placeholder }
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
  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? { nil }
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
  func acceptInvite(token: String) async throws {}
  func declineInvite(token: String) async throws {}
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws {}
}
