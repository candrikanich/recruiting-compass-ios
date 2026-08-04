import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OnboardingViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: OnboardingViewModel!
  var mockOnboardingService: MockOnboardingService!
  var mockPreferenceManager: MockPreferenceManager!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!
  var didCompleteCallCount = 0

  override func setUp() {
    mockOnboardingService = MockOnboardingService()
    mockPreferenceManager = MockPreferenceManager()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockAuthManager.setMockUser(userMock())
    didCompleteCallCount = 0

    viewModel = OnboardingViewModel(
      onComplete: { [weak self] in self?.didCompleteCallCount += 1 },
      onboardingService: mockOnboardingService,
      preferenceService: mockPreferenceManager,
      authManager: mockAuthManager,
      familyService: mockFamilyService
    )
  }

  override func tearDown() {
    viewModel = nil
    mockOnboardingService = nil
    mockPreferenceManager = nil
    mockAuthManager = nil
    mockFamilyService = nil
  }

  // MARK: - loadExistingData

  func testLoadExistingData_populatesFromExistingPreferences() async {
    var existing = PlayerDetails.default
    existing.graduationYear = 2027
    existing.primarySport = "Baseball"
    existing.primaryPosition = "Pitcher"
    mockPreferenceManager.fetchPreferencesResult = .success(existing)

    await viewModel.loadExistingData()

    XCTAssertEqual(viewModel.graduationYear, 2027)
    XCTAssertEqual(viewModel.primarySport, "Baseball")
    XCTAssertEqual(viewModel.primaryPosition, "Pitcher")
  }

  func testLoadExistingData_noExistingPreferences_leavesFieldsUnset() async {
    mockPreferenceManager.fetchPreferencesResult = .success(nil)

    await viewModel.loadExistingData()

    XCTAssertNil(viewModel.graduationYear)
    XCTAssertEqual(viewModel.primarySport, "")
  }

  // MARK: - isEmailInviteValid

  func testIsEmailInviteValid_missingAtSign_isFalse() {
    viewModel.inviteEmail = "invalid.example.com"
    XCTAssertFalse(viewModel.isEmailInviteValid)
  }

  func testIsEmailInviteValid_wellFormed_isTrue() {
    viewModel.inviteEmail = "parent@example.com"
    XCTAssertTrue(viewModel.isEmailInviteValid)
  }

  // MARK: - sendParentInvite

  func testSendParentInvite_invalidEmail_isNoOp() async {
    viewModel.inviteEmail = "not-an-email"
    await viewModel.sendParentInvite()
    XCTAssertEqual(mockFamilyService.sendEmailInviteCallCount, 0)
  }

  func testSendParentInvite_noFamilyUnit_setsError() async {
    viewModel.inviteEmail = "parent@example.com"
    mockFamilyService.stubbedFamilyUnit = nil

    await viewModel.sendParentInvite()

    XCTAssertEqual(viewModel.errorMessage, "Family not set up yet. Complete onboarding first.")
    XCTAssertEqual(mockFamilyService.sendEmailInviteCallCount, 0)
  }

  func testSendParentInvite_success_sendsInviteAndClearsField() async {
    viewModel.inviteEmail = "parent@example.com"
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()

    await viewModel.sendParentInvite()

    XCTAssertEqual(mockFamilyService.sendEmailInviteCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastInviteEmail, "parent@example.com")
    XCTAssertEqual(viewModel.inviteEmail, "")
    XCTAssertTrue(viewModel.isInviteSent)
  }

  func testSendParentInvite_serviceThrows_setsErrorMessage() async {
    viewModel.inviteEmail = "parent@example.com"
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockFamilyService.shouldSucceed = false

    await viewModel.sendParentInvite()

    XCTAssertEqual(viewModel.errorMessage, "Failed to send invite. You can do this later from Family Management.")
    XCTAssertFalse(viewModel.isInviteSent)
  }

  // MARK: - validateStep (zip code, step 3 only)

  func testValidateStep_notStep3_alwaysValid() {
    viewModel.currentStep = 1
    XCTAssertTrue(viewModel.validateStep())
  }

  func testValidateStep_step3_emptyZip_isInvalid() {
    viewModel.currentStep = 3
    viewModel.zipCode = ""
    XCTAssertFalse(viewModel.validateStep())
    XCTAssertEqual(viewModel.zipCodeError, "Zip code is required")
  }

  func testValidateStep_step3_nonNumericZip_isInvalid() {
    viewModel.currentStep = 3
    viewModel.zipCode = "abcde"
    XCTAssertFalse(viewModel.validateStep())
    XCTAssertEqual(viewModel.zipCodeError, "Please enter a valid 5-digit zip code")
  }

  func testValidateStep_step3_wrongLengthZip_isInvalid() {
    viewModel.currentStep = 3
    viewModel.zipCode = "1234"
    XCTAssertFalse(viewModel.validateStep())
  }

  func testValidateStep_step3_validZip_isValid() {
    viewModel.currentStep = 3
    viewModel.zipCode = "90210"
    XCTAssertTrue(viewModel.validateStep())
    XCTAssertNil(viewModel.zipCodeError)
  }

  // MARK: - nextScreen

  func testNextScreen_step1_advancesWithoutSaving() async {
    viewModel.currentStep = 1
    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 2)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.count, 0)
  }

  func testNextScreen_step2_savesPlayerPreferencesThenAdvances() async {
    viewModel.currentStep = 2
    viewModel.graduationYear = 2028
    viewModel.primarySport = "Softball"

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 3)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.count, 1)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.first?.category, .player)
  }

  func testNextScreen_step3_invalidZip_doesNotAdvance() async {
    viewModel.currentStep = 3
    viewModel.zipCode = ""

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 3)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.count, 0)
  }

  func testNextScreen_step3_savesLocationThenAdvances() async {
    viewModel.currentStep = 3
    viewModel.zipCode = "90210"

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 4)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.first?.category, .location)
  }

  func testNextScreen_step4_savesAcademicsThenAdvances() async {
    viewModel.currentStep = 4
    viewModel.gpa = 3.8
    viewModel.satScore = 1400

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 5)
    XCTAssertEqual(mockPreferenceManager.savePreferencesCalls.last?.category, .player)
  }

  func testNextScreen_lastStep_completesOnboarding() async {
    viewModel.currentStep = OnboardingConstants.totalSteps

    await viewModel.nextScreen()

    XCTAssertEqual(mockOnboardingService.completeOnboardingCallCount, 1)
    XCTAssertEqual(didCompleteCallCount, 1)
  }

  func testNextScreen_saveFails_setsErrorAndDoesNotAdvance() async {
    viewModel.currentStep = 2
    mockPreferenceManager.savePreferencesResult = .failure(NSError(domain: "test", code: 1))

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.currentStep, 2)
    XCTAssertEqual(viewModel.errorMessage, "Couldn't save this step. Please try again.")
  }

  // MARK: - completeOnboarding (via nextScreen at last step)

  func testCompleteOnboarding_noUser_setsErrorAndSkipsService() async {
    mockAuthManager.user = nil
    viewModel.currentStep = OnboardingConstants.totalSteps

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.errorMessage, "User not authenticated")
    XCTAssertEqual(mockOnboardingService.completeOnboardingCallCount, 0)
  }

  func testCompleteOnboarding_serviceThrows_setsErrorMessage() async {
    viewModel.currentStep = OnboardingConstants.totalSteps
    mockOnboardingService.shouldThrowError = true

    await viewModel.nextScreen()

    XCTAssertEqual(viewModel.errorMessage, "Couldn't finish setup. Please try again.")
    XCTAssertEqual(didCompleteCallCount, 0)
  }

  // MARK: - previousScreen / skipStep

  func testPreviousScreen_decrementsWhenAboveFirstStep() {
    viewModel.currentStep = 3
    viewModel.previousScreen()
    XCTAssertEqual(viewModel.currentStep, 2)
  }

  func testPreviousScreen_atFirstStep_isNoOp() {
    viewModel.currentStep = 1
    viewModel.previousScreen()
    XCTAssertEqual(viewModel.currentStep, 1)
  }

  func testSkipStep_advancesWhenNotLastStep() async {
    viewModel.currentStep = 2
    await viewModel.skipStep()
    XCTAssertEqual(viewModel.currentStep, 3)
  }

  func testSkipStep_atLastStep_isNoOp() async {
    viewModel.currentStep = OnboardingConstants.totalSteps
    await viewModel.skipStep()
    XCTAssertEqual(viewModel.currentStep, OnboardingConstants.totalSteps)
  }

  // MARK: - Misc

  func testClearError_resetsErrorMessage() {
    viewModel.errorMessage = "some error"
    viewModel.clearError()
    XCTAssertNil(viewModel.errorMessage)
  }

  func testOnSportChange_resetsPosition() {
    viewModel.primaryPosition = "Pitcher"
    viewModel.onSportChange()
    XCTAssertEqual(viewModel.primaryPosition, "")
  }

  func testGraduationYearDisplay_getReturnsStringOfYear() {
    viewModel.graduationYear = 2029
    XCTAssertEqual(viewModel.graduationYearDisplay, "2029")
  }

  func testGraduationYearDisplay_getWithNilYear_returnsEmptyString() {
    viewModel.graduationYear = nil
    XCTAssertEqual(viewModel.graduationYearDisplay, "")
  }

  func testGraduationYearDisplay_setParsesStringToInt() {
    viewModel.graduationYearDisplay = "2030"
    XCTAssertEqual(viewModel.graduationYear, 2030)
  }

  // MARK: - Helpers

  private func makeFamilyUnit() -> FamilyUnit {
    FamilyUnit(
      id: "family-1",
      createdByUserId: "user-1",
      familyName: "Test Family",
      familyCode: "FAM-ABC123",
      codeGeneratedAt: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil,
      pendingPlayerDetails: nil
    )
  }

  private func userMock() -> User {
    User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }
}
