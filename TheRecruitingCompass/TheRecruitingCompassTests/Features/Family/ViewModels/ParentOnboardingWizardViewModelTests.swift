import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ParentOnboardingWizardViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: ParentOnboardingWizardViewModel!
  var mockFamilyService: MockFamilyService!
  var mockAuthManager: MockAuthManager!
  var stubSchoolsRepository: StubParentSchoolsRepository!
  var stubRecommendationService: StubParentRecommendationService!

  override func setUp() {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    stubSchoolsRepository = StubParentSchoolsRepository()
    stubRecommendationService = StubParentRecommendationService()
    mockAuthManager.setMockUser(User(
      id: "parent-1",
      email: "parent@example.com",
      emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .parent
    ))
    viewModel = ParentOnboardingWizardViewModel(
      familyService: mockFamilyService,
      authManager: mockAuthManager,
      schoolsRepository: stubSchoolsRepository,
      recommendationService: stubRecommendationService
    )
  }

  override func tearDown() {
    viewModel = nil
    mockFamilyService = nil
    mockAuthManager = nil
    stubSchoolsRepository = nil
    stubRecommendationService = nil
  }

  // MARK: - Step Navigation

  func testNextStep_advancesFromPlayerDetailsToSchoolsToExplore() {
    viewModel.nextStep()
    XCTAssertEqual(viewModel.currentStep, .schoolsToExplore)
  }

  func testNextStep_atLastStep_isNoOp() {
    viewModel.nextStep()
    viewModel.nextStep()
    XCTAssertEqual(viewModel.currentStep, .schoolsToExplore)
  }

  func testPreviousStep_returnsToPlayerDetails() {
    viewModel.nextStep()
    viewModel.previousStep()
    XCTAssertEqual(viewModel.currentStep, .playerDetails)
  }

  func testPreviousStep_atFirstStep_isNoOp() {
    viewModel.previousStep()
    XCTAssertEqual(viewModel.currentStep, .playerDetails)
  }

  func testNextStep_clearsErrorMessage() {
    viewModel.errorMessage = "some error"
    viewModel.nextStep()
    XCTAssertNil(viewModel.errorMessage)
  }

  // MARK: - onSportChange / onDateOfBirthChange

  func testOnSportChange_resetsPosition() {
    viewModel.playerPosition = "Pitcher"
    viewModel.onSportChange()
    XCTAssertEqual(viewModel.playerPosition, "")
  }

  func testOnDateOfBirthChange_setsConfirmedFlag() {
    XCTAssertFalse(viewModel.hasConfirmedDateOfBirth)
    viewModel.onDateOfBirthChange()
    XCTAssertTrue(viewModel.hasConfirmedDateOfBirth)
  }

  // MARK: - isPlayerUnderAge

  func testIsPlayerUnderAge_youngDOB_isTrue() {
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now
    XCTAssertTrue(viewModel.isPlayerUnderAge)
  }

  func testIsPlayerUnderAge_adultDOB_isFalse() {
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now
    XCTAssertFalse(viewModel.isPlayerUnderAge)
  }

  // MARK: - isPlayerDetailsValid

  func testIsPlayerDetailsValid_emptyFirstName_isFalse() {
    viewModel.playerFirstName = ""
    viewModel.hasConfirmedDateOfBirth = true
    XCTAssertFalse(viewModel.isPlayerDetailsValid)
  }

  func testIsPlayerDetailsValid_dobNotConfirmed_isFalse() {
    viewModel.playerFirstName = "Alex"
    viewModel.hasConfirmedDateOfBirth = false
    XCTAssertFalse(viewModel.isPlayerDetailsValid)
  }

  func testIsPlayerDetailsValid_underage_isFalse() {
    viewModel.playerFirstName = "Alex"
    viewModel.hasConfirmedDateOfBirth = true
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now
    XCTAssertFalse(viewModel.isPlayerDetailsValid)
  }

  func testIsPlayerDetailsValid_validState_isTrue() {
    viewModel.playerFirstName = "Alex"
    viewModel.hasConfirmedDateOfBirth = true
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now
    XCTAssertTrue(viewModel.isPlayerDetailsValid)
  }

  // MARK: - isInviteStepValid

  func testIsInviteStepValid_missingAtSign_isFalse() {
    viewModel.inviteEmail = "invalid.example.com"
    XCTAssertFalse(viewModel.isInviteStepValid)
  }

  func testIsInviteStepValid_missingDot_isFalse() {
    viewModel.inviteEmail = "invalid@examplecom"
    XCTAssertFalse(viewModel.isInviteStepValid)
  }

  func testIsInviteStepValid_wellFormed_isTrue() {
    viewModel.inviteEmail = "parent@example.com"
    XCTAssertTrue(viewModel.isInviteStepValid)
  }

  // MARK: - loadFamilyCode

  func testLoadFamilyCode_success_setsFamilyCode() async {
    mockFamilyService.mockCreateFamilyResponse = CreateFamilyResponse(
      success: true,
      familyCode: "FAM-TEST01",
      familyId: "family-1",
      familyName: "Test Family"
    )

    await viewModel.loadFamilyCode()

    XCTAssertEqual(viewModel.familyCode, "FAM-TEST01")
    XCTAssertFalse(viewModel.isLoadingFamilyCode)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadFamilyCode_failure_setsErrorAndClearsCode() async {
    mockFamilyService.shouldSucceed = false

    await viewModel.loadFamilyCode()

    XCTAssertNil(viewModel.familyCode)
    XCTAssertEqual(viewModel.errorMessage, "Couldn't load your family code. Please try again.")
  }

  // MARK: - sendInvite

  func testSendInvite_invalidEmail_setsErrorAndSkipsService() async {
    viewModel.inviteEmail = "not-an-email"

    await viewModel.sendInvite()

    XCTAssertEqual(viewModel.errorMessage, "Please enter a valid email address")
    XCTAssertEqual(mockFamilyService.sendEmailInviteCallCount, 0)
  }

  func testSendInvite_success_setsSuccessStateAndCompletes() async {
    viewModel.inviteEmail = "coach@example.com"
    viewModel.playerFirstName = "Alex"
    viewModel.playerLastName = "Rivera"
    viewModel.playerSport = "Baseball"
    viewModel.playerGraduationYear = 2028

    await viewModel.sendInvite()

    XCTAssertEqual(mockFamilyService.sendEmailInviteCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastInviteEmail, "coach@example.com")
    XCTAssertEqual(viewModel.successMessage, "Invite sent to coach@example.com!")
    XCTAssertTrue(viewModel.showSuccessToast)
    XCTAssertTrue(viewModel.didComplete)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSendInvite_trimsWhitespaceFromEmail() async {
    viewModel.inviteEmail = "  coach@example.com  "

    await viewModel.sendInvite()

    XCTAssertEqual(mockFamilyService.lastInviteEmail, "coach@example.com")
  }

  func testSendInvite_serviceThrowsFamilyError_usesErrorDescription() async {
    viewModel.inviteEmail = "coach@example.com"
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.notAuthenticated

    await viewModel.sendInvite()

    XCTAssertEqual(viewModel.errorMessage, FamilyError.notAuthenticated.errorDescription)
    XCTAssertFalse(viewModel.didComplete)
  }

  func testSendInvite_serviceThrowsGenericError_usesFallbackMessage() async {
    viewModel.inviteEmail = "coach@example.com"
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = NSError(domain: "test", code: 1)

    await viewModel.sendInvite()

    XCTAssertEqual(viewModel.errorMessage, "Failed to send invite. Please try again.")
  }

  // MARK: - proceedFromPlayerDetails

  func testProceedFromPlayerDetails_invalid_isNoOp() async {
    viewModel.playerFirstName = ""

    await viewModel.proceedFromPlayerDetails()

    XCTAssertEqual(viewModel.currentStep, .playerDetails)
    XCTAssertEqual(mockFamilyService.savePlayerDetailsCallCount, 0)
  }

  func testProceedFromPlayerDetails_valid_savesDetailsAndAdvances() async {
    viewModel.playerFirstName = "Alex"
    viewModel.hasConfirmedDateOfBirth = true
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now
    viewModel.playerSport = "Baseball"
    viewModel.playerGraduationYear = 2028
    mockFamilyService.mockCreateFamilyResponse = CreateFamilyResponse(
      success: true,
      familyCode: "FAM-TEST01",
      familyId: "family-42",
      familyName: "Test Family"
    )

    await viewModel.proceedFromPlayerDetails()

    XCTAssertEqual(viewModel.currentStep, .schoolsToExplore)
    XCTAssertEqual(mockFamilyService.savePlayerDetailsCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastSavePlayerDetailsFamilyId, "family-42")
    XCTAssertEqual(mockFamilyService.lastSavePlayerDetails?.firstName, "Alex")
    XCTAssertEqual(mockFamilyService.lastSavePlayerDetails?.sport, "Baseball")
    XCTAssertEqual(viewModel.familyCode, "FAM-TEST01")
    XCTAssertNil(viewModel.errorMessage)
  }

  func testProceedFromPlayerDetails_serviceFails_staysOnStepWithError() async {
    viewModel.playerFirstName = "Alex"
    viewModel.hasConfirmedDateOfBirth = true
    viewModel.playerDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.notAuthenticated

    await viewModel.proceedFromPlayerDetails()

    XCTAssertEqual(viewModel.currentStep, .playerDetails)
    XCTAssertEqual(viewModel.errorMessage, FamilyError.notAuthenticated.errorDescription)
  }

  // MARK: - loadRecommendations

  func testLoadRecommendations_populatesFromService() async {
    stubRecommendationService.stubbedRecommendations = [
      SchoolRecommendation(catalogKey: "duke", name: "Duke", score: 0.9, reasons: [])
    ]

    await viewModel.loadRecommendations()

    XCTAssertEqual(viewModel.recommendations.count, 1)
    XCTAssertEqual(viewModel.recommendations.first?.name, "Duke")
    XCTAssertFalse(viewModel.isLoadingRecommendations)
  }

  func testLoadRecommendations_serviceFails_clearsRecommendations() async {
    stubRecommendationService.errorToThrow = NSError(domain: "test", code: 1)
    viewModel.recommendations = [SchoolRecommendation(catalogKey: "stale", name: "Stale U", score: 0.1, reasons: [])]

    await viewModel.loadRecommendations()

    XCTAssertTrue(viewModel.recommendations.isEmpty)
  }

  // MARK: - addSchool

  func testAddSchool_noFamilyUnit_returnsFalse() async {
    mockFamilyService.stubbedFamilyUnit = nil
    let recommendation = SchoolRecommendation(catalogKey: "duke", name: "Duke", score: 0.9, reasons: [])

    let result = await viewModel.addSchool(recommendation)

    XCTAssertFalse(result)
  }

  func testAddSchool_success_removesRecommendationAndIncrementsCount() async {
    mockFamilyService.stubbedFamilyUnit = FamilyUnit(
      id: "family-1",
      createdByUserId: "parent-1",
      familyName: "Test Family",
      familyCode: "FAM-TEST01",
      codeGeneratedAt: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
    let recommendation = SchoolRecommendation(catalogKey: "duke", name: "Duke", score: 0.9, reasons: [])
    viewModel.recommendations = [recommendation]

    let result = await viewModel.addSchool(recommendation)

    XCTAssertTrue(result)
    XCTAssertTrue(viewModel.recommendations.isEmpty)
    XCTAssertEqual(viewModel.schoolsAdded, 1)
  }

  // MARK: - dismissRecommendation

  func testDismissRecommendation_removesFromList() async {
    let recommendation = SchoolRecommendation(catalogKey: "duke", name: "Duke", score: 0.9, reasons: [])
    viewModel.recommendations = [recommendation]

    await viewModel.dismissRecommendation(recommendation)

    XCTAssertTrue(viewModel.recommendations.isEmpty)
    XCTAssertEqual(stubRecommendationService.dismissedKeys, ["duke"])
  }

  // MARK: - finishOnboarding

  func testFinishOnboarding_setsDidComplete() {
    XCTAssertFalse(viewModel.didComplete)
    viewModel.finishOnboarding()
    XCTAssertTrue(viewModel.didComplete)
  }
}

// MARK: - Minimal stubs for schools/recommendations dependencies

final class StubParentSchoolsRepository: SchoolsRepository, @unchecked Sendable {
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

final class StubParentRecommendationService: SchoolRecommendationManaging, @unchecked Sendable {
  var stubbedRecommendations: [SchoolRecommendation] = []
  var errorToThrow: Error?
  var dismissedKeys: [String] = []

  func fetchRecommendations(athleteId: String, limit: Int) async throws -> [SchoolRecommendation] {
    if let errorToThrow { throw errorToThrow }
    return stubbedRecommendations
  }

  func dismissRecommendation(catalogKey: String, athleteId: String) async throws {
    dismissedKeys.append(catalogKey)
  }
}
