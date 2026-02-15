import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SignupViewModelTests: XCTestCase {
  var sut: SignupViewModel!
  var mockAuthManager: MockAuthManager!

  @MainActor
  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    sut = SignupViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func fillValidForm(role: UserRole = .parent) {
    sut.selectRole(role)
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true
  }

  // MARK: - Initialization Tests

  func testInitialState() {
    XCTAssertNil(sut.selectedRole)
    XCTAssertFalse(sut.showForm)
    XCTAssertEqual(sut.fullName, "")
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
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.familyCode = "FAM-ABC12345"

    sut.backToRoleSelection()

    XCTAssertFalse(sut.showForm)
    XCTAssertEqual(sut.fullName, "")
    XCTAssertEqual(sut.email, "")
    XCTAssertEqual(sut.password, "")
    XCTAssertEqual(sut.confirmPassword, "")
    XCTAssertEqual(sut.familyCode, "")
    XCTAssertFalse(sut.termsAccepted)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Validation Tests

  func testValidateFullName() {
    sut.fullName = "John Doe"
    sut.validateFullName()

    XCTAssertNil(sut.fieldErrors[.fullName])
  }

  func testValidateFullNameWithError() {
    sut.fullName = "J"
    sut.validateFullName()

    XCTAssertNotNil(sut.fieldErrors[.fullName])
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

  func testValidateFamilyCodeForStudentRole() {
    sut.selectedRole = .player
    sut.familyCode = "FAM-ABC12345"
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateFamilyCodeOptionalForStudentRole() {
    sut.selectedRole = .player
    sut.familyCode = ""
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateFamilyCodeNotRequiredForParentRole() {
    sut.selectedRole = .parent
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

  func testIsFormValidForStudentRoleWithoutFamilyCode() {
    fillValidForm(role: .player)
    sut.familyCode = ""

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForStudentRoleWithFamilyCode() {
    fillValidForm(role: .player)
    sut.familyCode = "FAM-ABC12345"

    XCTAssertTrue(sut.isFormValid)
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
    sut.fullName = "John Doe"
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

  func testSignupSuccessForStudentRole() async {
    fillValidForm(role: .player)

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupSuccessForPlayerRole() async {
    fillValidForm(role: .player)

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  // MARK: - Signup Validation Guard Tests

  func testSignupWithInvalidFormDoesNotCallAuthManager() async {
    sut.selectRole(.parent)
    sut.fullName = ""
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
    sut.fullName = ""
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
    sut.fullName = "John Doe"
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
    sut.fullName = "J"
    sut.email = "bad"
    sut.password = "x"
    sut.confirmPassword = "y"
    sut.termsAccepted = false

    await sut.signup()

    XCTAssertNotNil(sut.fieldErrors[.fullName])
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

  func testSignupSendsFamilyCodeForStudentRole() async {
    fillValidForm(role: .player)
    sut.familyCode = "FAM-ABC12345"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupSendsNilFamilyCodeForParentRole() async {
    fillValidForm(role: .parent)
    sut.familyCode = "FAM-SHOULDBEIGNORED"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupSendsNilFamilyCodeWhenEmptyForStudentRole() async {
    fillValidForm(role: .player)
    sut.familyCode = ""

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  func testSignupTrimsWhitespaceFamilyCode() async {
    fillValidForm(role: .player)
    sut.familyCode = "   "

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertTrue(sut.shouldNavigateToVerifyEmail)
  }

  // MARK: - Signup Integration / State Transition Tests

  func testSignupRetryAfterErrorDismissal() async {
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
    fillValidForm(role: .player)
    sut.familyCode = "INVALID"

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
    XCTAssertFalse(sut.shouldNavigateToVerifyEmail)
  }
}
