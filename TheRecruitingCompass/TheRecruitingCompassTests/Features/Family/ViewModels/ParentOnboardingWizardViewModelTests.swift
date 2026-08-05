import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ParentOnboardingWizardViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: ParentOnboardingWizardViewModel!
  var mockFamilyService: MockFamilyService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    viewModel = ParentOnboardingWizardViewModel(
      familyService: mockFamilyService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockFamilyService = nil
    mockAuthManager = nil
  }

  // MARK: - Step Navigation

  func testNextStep_advancesFromPlayerDetailsToSendInvite() {
    viewModel.nextStep()
    XCTAssertEqual(viewModel.currentStep, .sendInvite)
  }

  func testNextStep_atLastStep_isNoOp() {
    viewModel.nextStep()
    viewModel.nextStep()
    XCTAssertEqual(viewModel.currentStep, .sendInvite)
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
}
