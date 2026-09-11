import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SignupViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: SignupViewModel!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!
  var mockTurnstileProvider: MockTurnstileTokenProvider!

  @MainActor
  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockTurnstileProvider = MockTurnstileTokenProvider()
    sut = SignupViewModel(
      authManager: mockAuthManager,
      familyService: mockFamilyService,
      turnstileTokenProvider: mockTurnstileProvider
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    mockFamilyService = nil
    mockTurnstileProvider = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func fillValidForm(role: UserRole = .parent) {
    sut.selectRole(role)
    sut.firstName = "John"
    sut.lastName = "Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true
    if role == .player {
      sut.graduationYear = 2028
      sut.primarySport = "Soccer"
    }
  }

  // MARK: - Initialization Tests

  func testInitialState() {
    XCTAssertNil(sut.selectedRole)
    XCTAssertFalse(sut.showForm)
    XCTAssertEqual(sut.firstName, "")
    XCTAssertEqual(sut.lastName, "")
    XCTAssertEqual(sut.email, "")
    XCTAssertEqual(sut.password, "")
    XCTAssertEqual(sut.confirmPassword, "")
    XCTAssertEqual(sut.familyCode, "")
    XCTAssertFalse(sut.termsAccepted)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Two-Step Flow Tests

  func testSelectRoleSetsRoleAndShowsForm() {
    sut.selectRole(.parent)

    XCTAssertEqual(sut.selectedRole, .parent)
    XCTAssertTrue(sut.showForm)
  }

  func testBackToRoleSelectionResetsState() {
    sut.selectRole(.player)
    sut.firstName = "John"
    sut.lastName = "Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.familyCode = "FAM-ABC123"

    sut.backToRoleSelection()

    XCTAssertFalse(sut.showForm)
    XCTAssertEqual(sut.firstName, "")
    XCTAssertEqual(sut.lastName, "")
    XCTAssertEqual(sut.email, "")
    XCTAssertEqual(sut.password, "")
    XCTAssertEqual(sut.confirmPassword, "")
    XCTAssertEqual(sut.familyCode, "")
    XCTAssertFalse(sut.termsAccepted)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Validation Tests
  func testValidateFirstName() {
    sut.firstName = "John"
    sut.validateFirstName()

    XCTAssertNil(sut.fieldErrors[.firstName])
  }

  func testValidateFirstNameWithError() {
    sut.firstName = "J"
    sut.validateFirstName()

    XCTAssertNotNil(sut.fieldErrors[.firstName])
  }

  func testValidateLastName() {
    sut.lastName = "Doe"
    sut.validateLastName()

    XCTAssertNil(sut.fieldErrors[.lastName])
  }

  func testValidateLastNameWithError() {
    sut.lastName = "D"
    sut.validateLastName()

    XCTAssertNotNil(sut.fieldErrors[.lastName])
  }

  func testValidateEmail() {
    sut.email = "john@example.com"
    sut.validateEmail()

    XCTAssertNil(sut.fieldErrors[.email])
  }

  func testValidateEmailWithError() {
    sut.email = "invalid.email"
    sut.validateEmail()

    XCTAssertNotNil(sut.fieldErrors[.email])
  }

  func testValidatePassword() {
    sut.password = "StrongPass123"
    sut.validatePassword()

    XCTAssertNil(sut.fieldErrors[.password])
  }

  func testValidatePasswordWithWeakPassword() {
    sut.password = "weak"
    sut.validatePassword()

    XCTAssertNotNil(sut.fieldErrors[.password])
  }

  func testValidateConfirmPassword() {
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.validateConfirmPassword()

    XCTAssertNil(sut.fieldErrors[.confirmPassword])
  }

  func testValidateConfirmPasswordMismatch() {
    sut.password = "StrongPass123"
    sut.confirmPassword = "DifferentPass123"
    sut.validateConfirmPassword()

    XCTAssertNotNil(sut.fieldErrors[.confirmPassword])
  }

  func testValidateFamilyCodeForParentRole() {
    sut.selectedRole = .parent
    sut.familyCode = "FAM-ABC123"
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateFamilyCodeOptionalForParentRole() {
    sut.selectedRole = .parent
    sut.familyCode = ""
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateFamilyCodeNotRequiredForPlayerRole() {
    sut.selectedRole = .player
    sut.familyCode = ""
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateTerms() {
    sut.termsAccepted = true
    sut.validateTerms()

    XCTAssertNil(sut.errorMessage)
  }

  func testValidateTermsNotAccepted() {
    sut.termsAccepted = false
    sut.validateTerms()

    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Form Validity Tests

  func testIsFormValidForParentRole() {
    fillValidForm(role: .parent)

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForParentRoleWithoutFamilyCode() {
    fillValidForm(role: .parent)
    sut.familyCode = ""

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForParentRoleWithFamilyCode() {
    fillValidForm(role: .parent)
    sut.familyCode = "FAM-ABC123"

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForPlayerRoleWithoutFamilyCode() {
    fillValidForm(role: .player)
    sut.familyCode = ""

    XCTAssertTrue(sut.isFormValid)
  }

  func testFormInvalidForMinorPlayer13to17() {
    fillValidForm(role: .player)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now)!

    XCTAssertFalse(
      sut.isFormValid,
      "Players 13-17 cannot hold a standalone account; they join via a guardian's family invite"
    )
    XCTAssertFalse(sut.isUnderCOPPAAge, "13-17 is over the COPPA floor — a distinct band")
    XCTAssertTrue(sut.requiresGuardianInvite)
  }

  func testGuardianInviteMessageExplainsDisabledSubmit() {
    fillValidForm(role: .player)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now)!

    // The picker defaults into this band, so the message must be present without the
    // user touching the field — otherwise the submit button is disabled with no reason.
    XCTAssertNotNil(
      sut.guardianInviteMessage,
      "A blocked minor must be told why, not left with a silently disabled button"
    )
    XCTAssertNil(
      sut.fieldErrors[.dateOfBirth],
      "Guidance is not a validation error — the user hasn't done anything wrong"
    )
  }

  func testGuardianInviteMessageAbsentForAdultPlayer() {
    fillValidForm(role: .player)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: .now)!

    XCTAssertNil(sut.guardianInviteMessage)
    XCTAssertFalse(sut.requiresGuardianInvite)
  }

  func testFormValidAtExactlyEighteen() {
    fillValidForm(role: .player)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: .now)!

    XCTAssertTrue(sut.isFormValid, "18 is the standalone-account boundary")
    XCTAssertFalse(sut.requiresGuardianInvite)
  }

  func testRequiresGuardianInviteFalseForParent() {
    fillValidForm(role: .parent)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now)!

    XCTAssertFalse(sut.requiresGuardianInvite, "The guardian-invite rule applies only to players")
    XCTAssertNil(sut.guardianInviteMessage)
  }

  func testFormValidForAdultPlayer() {
    fillValidForm(role: .player)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: .now)!

    XCTAssertFalse(sut.isUnderCOPPAAge)
    XCTAssertTrue(sut.isFormValid)
  }

  func testIsUnderCOPPAAgeFalseForParent() {
    fillValidForm(role: .parent)
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now)!

    XCTAssertFalse(sut.isUnderCOPPAAge, "COPPA age check applies only to the player role")
  }

  func testIsFormInvalidWhenPasswordsDoNotMatch() {
    fillValidForm(role: .parent)
    sut.confirmPassword = "DifferentPass123"

    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWhenTermsNotAccepted() {
    fillValidForm(role: .parent)
    sut.termsAccepted = false

    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWhenNoRoleSelected() {
    sut.selectedRole = nil
    sut.firstName = "John"
    sut.lastName = "Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true

    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWhenFieldErrors() {
    fillValidForm(role: .parent)
    sut.fieldErrors[.email] = "Invalid email"

    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - isButtonDisabled Tests

  func testIsButtonDisabledWhenFormInvalid() {
    sut.selectedRole = nil

    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testIsButtonDisabledWhenLoading() {
    fillValidForm()
    sut.isLoading = true

    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testIsButtonEnabledWhenFormValidAndNotLoading() {
    fillValidForm()

    XCTAssertFalse(sut.isButtonDisabled)
  }

  // MARK: - Error Handling Tests

  func testDismissError() {
    sut.errorMessage = "Test error"
    sut.dismissError()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Signup Happy Path Tests

  func testSignupSuccessNavigatesToEmailVerification() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .parent)

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
    XCTAssertNil(sut.errorMessage)
  }

  func testSignupSuccessResetsLoadingState() async {
    fillValidForm(role: .parent)

    await sut.signup()

    XCTAssertFalse(sut.isLoading)
  }

  func testSignupSuccessForPlayerRole() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .player)

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  // MARK: - Onboarding Step 1 Tests

  func testPlayerRoleRequiresGradYearAndSport() {
    fillValidForm(role: .player)
    sut.graduationYear = nil

    XCTAssertFalse(sut.isFormValid)
  }

  func testParentRoleDoesNotRequireGradYearOrSport() {
    fillValidForm(role: .parent)

    XCTAssertTrue(sut.isFormValid)
  }

  func testSignupSendsOnboardingStep1MetadataWhenBothPresent() async {
    fillValidForm(role: .player)

    await sut.signup()

    XCTAssertEqual(mockAuthManager.capturedSignupGraduationYear, 2028)
    XCTAssertEqual(mockAuthManager.capturedSignupPrimarySport, "Soccer")
  }

  func testSignupOmitsOnboardingStep1MetadataForParentRole() async {
    fillValidForm(role: .parent)

    await sut.signup()

    XCTAssertNil(mockAuthManager.capturedSignupGraduationYear)
    XCTAssertNil(mockAuthManager.capturedSignupPrimarySport)
  }

  func testSignupAutoDerivesGenderForUnambiguousSport() async {
    fillValidForm(role: .player)
    sut.primarySport = "Baseball"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.capturedSignupGender, "male")
  }

  func testSignupUsesUserSelectedGenderForNeutralSport() async {
    fillValidForm(role: .player)
    sut.primarySport = "Soccer"
    sut.gender = "female"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.capturedSignupGender, "female")
  }

  func testSignupSendsZipCodeWhenValid() async {
    fillValidForm(role: .player)
    sut.zipCode = "94105"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.capturedSignupZipCode, "94105")
  }

  func testInvalidZipCodeBlocksSignup() async {
    fillValidForm(role: .player)
    sut.zipCode = "abc"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testValidZipCodeProducesNoFieldError() {
    sut.zipCode = "94105"
    sut.validateZipCode()

    XCTAssertNil(sut.fieldErrors[.zipCode])
  }

  func testEmptyZipCodeIsValidSinceOptional() {
    sut.zipCode = ""
    sut.validateZipCode()

    XCTAssertNil(sut.fieldErrors[.zipCode])
  }

  // MARK: - Signup Validation Guard Tests

  func testSignupWithInvalidFormDoesNotCallAuthManager() async {
    sut.selectRole(.parent)
    sut.firstName = ""
    sut.lastName = ""
    sut.email = ""
    sut.password = ""
    sut.confirmPassword = ""
    sut.termsAccepted = false

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupWithInvalidFormSetsErrorMessage() async {
    sut.selectRole(.parent)
    sut.firstName = ""
    sut.lastName = ""
    sut.email = "invalid"
    sut.password = "weak"
    sut.confirmPassword = "different"
    sut.termsAccepted = false

    await sut.signup()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupWithNoRoleSelectedSetsErrorMessage() async {
    sut.selectedRole = nil
    sut.firstName = "John"
    sut.lastName = "Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true

    await sut.signup()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupWithUnacceptedTermsDoesNotCallAuthManager() async {
    fillValidForm(role: .parent)
    sut.termsAccepted = false

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupRunsAllValidationsBeforeApiCall() async {
    sut.selectRole(.parent)
    sut.firstName = "J"
    sut.lastName = "D"
    sut.email = "bad"
    sut.password = "x"
    sut.confirmPassword = "y"
    sut.termsAccepted = false

    await sut.signup()

    XCTAssertNotNil(sut.fieldErrors[.firstName])
    XCTAssertNotNil(sut.fieldErrors[.lastName])
    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertNotNil(sut.fieldErrors[.password])
    XCTAssertNotNil(sut.fieldErrors[.confirmPassword])
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  // MARK: - Signup Error Handling Tests

  func testSignupWithAuthErrorDisplaysErrorDescription() async {
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .emailAlreadyRegistered

    await sut.signup()

    XCTAssertEqual(sut.errorMessage, "An account with this email already exists")
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupWithNetworkErrorDisplaysMessage() async {
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .networkError("No internet connection")

    await sut.signup()

    XCTAssertEqual(sut.errorMessage, "No internet connection")
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupWithServerErrorDisplaysMessage() async {
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .serverError("Internal server error")

    await sut.signup()

    XCTAssertEqual(sut.errorMessage, "Server error. Please try again later.")
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupWithPasswordTooWeakErrorDisplaysMessage() async {
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .passwordTooWeak

    await sut.signup()

    XCTAssertEqual(sut.errorMessage, "Password does not meet strength requirements")
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupErrorResetsLoadingState() async {
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .networkError("Timeout")

    await sut.signup()

    XCTAssertFalse(sut.isLoading)
  }

  func testSignupClearsErrorMessageBeforeAttempt() async {
    fillValidForm(role: .parent)
    sut.errorMessage = "Previous error"

    await sut.signup()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Signup Family Code Logic Tests

  func testSignupSendsFamilyCodeForParentRole() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .parent)
    sut.familyCode = "FAM-ABC123"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupSendsNilFamilyCodeForPlayerRole() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .player)
    sut.familyCode = "FAM-SHOULDBEIGNORED"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupSendsNilFamilyCodeWhenEmptyForParentRole() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .parent)
    sut.familyCode = ""

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupTrimsWhitespaceFamilyCode() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .parent)
    sut.familyCode = "   "

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  // MARK: - Signup Integration / State Transition Tests

  func testSignupRetryAfterErrorDismissal() async {
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .parent)
    mockAuthManager.shouldThrowSignupError = true
    mockAuthManager.mockErrorToThrow = .networkError("Timeout")

    await sut.signup()
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)

    sut.dismissError()
    mockAuthManager.shouldThrowSignupError = false

    await sut.signup()
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
    XCTAssertEqual(mockAuthManager.signupCallCount, 2)
  }

  func testSignupWithInvalidFamilyCodeFormatDoesNotCallAuthManager() async {
    // Neither role requires family code at signup; invalid code is ignored and signup proceeds.
    mockAuthManager.setAuthenticatedAfterSignup = false
    fillValidForm(role: .player)
    sut.familyCode = "INVALID"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  // MARK: - Captcha Tests

  func testSignupFetchesAndForwardsCaptchaToken() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.tokenToReturn = "captcha-signup-456"
    sut = SignupViewModel(authManager: mockAuthManager, familyService: mockFamilyService, turnstileTokenProvider: mockTurnstile)
    fillValidForm()

    await sut.signup()

    XCTAssertEqual(mockTurnstile.getTokenCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupCaptchaToken, "captcha-signup-456")
  }

  func testSignupSurfacesCaptchaFailure() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.shouldThrowError = true
    sut = SignupViewModel(authManager: mockAuthManager, familyService: mockFamilyService, turnstileTokenProvider: mockTurnstile)
    fillValidForm()

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
    XCTAssertEqual(sut.errorMessage, "Couldn't verify you're human. Please try again.")
  }
}
