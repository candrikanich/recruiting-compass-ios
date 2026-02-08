import XCTest
@testable import TheRecruitingCompass

@MainActor
final class LoginViewModelTests: XCTestCase {
  var sut: LoginViewModel!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    clearUserDefaults()
    mockAuthManager = MockAuthManager()
    sut = LoginViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    clearUserDefaults()
    super.tearDown()
  }

  private func clearUserDefaults() {
    UserDefaults.standard.removeObject(forKey: "cachedEmail")
    UserDefaults.standard.synchronize()
  }

  // MARK: - Initialization Tests

  func testLoginViewModelInitialState() {
    XCTAssertEqual(sut.email, "")
    XCTAssertEqual(sut.password, "")
    XCTAssertFalse(sut.rememberMe)
    XCTAssertFalse(sut.isLoading)
    XCTAssertFalse(sut.isValidating)
    XCTAssertNil(sut.errorMessage)
    XCTAssert(sut.fieldErrors.isEmpty)
    XCTAssertFalse(sut.showTimeoutBanner)
  }

  // MARK: - Happy Path Tests

  func testLoginWithValidCredentials() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertEqual(mockAuthManager.loginCallCount, 1)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(mockAuthManager.isAuthenticated)
  }

  func testValidateEmailOnBlurWithValidEmail() {
    sut.email = "user@example.com"
    sut.validateEmail()

    XCTAssertNil(sut.fieldErrors[.email])
  }

  func testValidateEmailOnBlurWithInvalidEmail() {
    sut.email = "invalid-email"
    sut.validateEmail()

    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertEqual(sut.fieldErrors[.email], "Invalid email address")
  }

  func testValidateEmailOnBlurWithEmptyEmail() {
    sut.email = ""
    sut.validateEmail()

    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertEqual(sut.fieldErrors[.email], "Email is required")
  }

  func testValidatePasswordOnBlurWithValidPassword() {
    sut.password = "ValidPassword123"
    sut.validatePassword()

    XCTAssertNil(sut.fieldErrors[.password])
  }

  func testValidatePasswordOnBlurWithShortPassword() {
    sut.password = "short"
    sut.validatePassword()

    XCTAssertNotNil(sut.fieldErrors[.password])
    XCTAssertEqual(sut.fieldErrors[.password], "Password must be at least 8 characters")
  }

  func testValidatePasswordOnBlurWithEmptyPassword() {
    sut.password = ""
    sut.validatePassword()

    XCTAssertNotNil(sut.fieldErrors[.password])
    XCTAssertEqual(sut.fieldErrors[.password], "Password is required")
  }

  func testSignInButtonDisabledWhenFormInvalid() {
    sut.email = ""
    sut.password = ""

    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testSignInButtonEnabledWhenFormValid() {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.validateEmail()
    sut.validatePassword()

    XCTAssertFalse(sut.isButtonDisabled)
  }

  func testSignInButtonDisabledDuringLoading() {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.validateEmail()
    sut.validatePassword()
    sut.isLoading = true

    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testRememberMeCanToggle() {
    XCTAssertFalse(sut.rememberMe)

    sut.rememberMe = true
    XCTAssertTrue(sut.rememberMe)

    sut.rememberMe = false
    XCTAssertFalse(sut.rememberMe)
  }

  func testIsFormValidWhenFieldsValid() {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.validateEmail()
    sut.validatePassword()

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidWhenEmailInvalid() {
    sut.email = "invalid"
    sut.password = "ValidPassword123"
    sut.validateEmail()
    sut.validatePassword()

    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormValidWhenPasswordInvalid() {
    sut.email = "user@example.com"
    sut.password = "short"
    sut.validateEmail()
    sut.validatePassword()

    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - Error Handling Tests

  func testInvalidCredentialsError() async {
    sut.email = "user@example.com"
    sut.password = "WrongPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Invalid email or password")
    XCTAssertFalse(mockAuthManager.isAuthenticated)
  }

  func testNetworkTimeoutError() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection timed out")

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Connection timed out")
  }

  func testNetworkError() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .networkError("No internet connection")

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "No internet connection")
    XCTAssertFalse(mockAuthManager.isAuthenticated)
  }

  func testTooManyAttemptsError() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .tooManyAttempts(retryAfter: "in 15 minutes")

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage?.contains("Too many login attempts") ?? false)
  }

  func testServerError() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .serverError("Internal server error")

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Server error. Please try again later.")
  }

  func testUserNotFoundError() async {
    sut.email = "nonexistent@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .userNotFound

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Email not found. Please sign up first.")
  }

  func testEmailNotVerifiedError() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .emailNotVerified

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage?.contains("verify your email") ?? false)
  }

  func testDismissError() {
    sut.errorMessage = "Test error"

    sut.dismissError()

    XCTAssertNil(sut.errorMessage)
  }

  func testLoginValidatesFieldsBeforeAttempt() async {
    sut.email = "invalid"
    sut.password = "short"

    await sut.login()

    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertNotNil(sut.fieldErrors[.password])
  }

  // MARK: - Edge Case Tests

  func testVeryLongEmailAddress() {
    let longEmail = String(repeating: "a", count: 200) + "@example.com"
    sut.email = longEmail
    sut.validateEmail()

    XCTAssertNotNil(sut.email)
    XCTAssertGreaterThan(sut.email.count, 200)
  }

  func testVeryLongPassword() {
    let longPassword = String(repeating: "P@ssw0rd", count: 50)
    sut.password = longPassword
    sut.validatePassword()

    XCTAssertNil(sut.fieldErrors[.password])
    XCTAssertGreaterThan(sut.password.count, 100)
  }

  func testRapidValidationCalls() {
    sut.email = "user@example.com"

    sut.validateEmail()
    sut.validateEmail()
    sut.validateEmail()

    XCTAssertNil(sut.fieldErrors[.email])
  }

  func testFieldErrorsIndependentValidation() {
    sut.email = "invalid-email"
    sut.validateEmail()

    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertNil(sut.fieldErrors[.password])
  }

  func testWhitespaceOnlyEmailIsInvalid() {
    sut.email = "   "
    sut.validateEmail()

    XCTAssertNotNil(sut.fieldErrors[.email])
  }

  func testWhitespaceEmailIsTrimmedBeforeValidation() {
    sut.email = "  user@example.com  "
    sut.validateEmail()

    XCTAssertNil(sut.fieldErrors[.email])
  }

  // MARK: - Performance Tests

  func testFormInputResponsiveness() {
    let startTime = CFAbsoluteTimeGetCurrent()

    sut.email = "user@example.com"
    sut.validateEmail()

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    XCTAssertLessThan(duration, 0.1)
  }

  func testPasswordInputResponsiveness() {
    let startTime = CFAbsoluteTimeGetCurrent()

    sut.password = "ValidPassword123"
    sut.validatePassword()

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    XCTAssertLessThan(duration, 0.1)
  }

  // MARK: - State Transition Tests

  func testFieldErrorsResetOnNewInput() {
    sut.email = "invalid"
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors[.email])

    sut.email = "user@example.com"
    sut.validateEmail()

    XCTAssertNil(sut.fieldErrors[.email])
  }

  func testErrorMessageClearedOnNewLogin() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.errorMessage = "Previous error"

    await sut.login()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Timeout Banner Tests

  func testTimeoutBannerShowsWhenTimeoutReasonProvided() async {
    let viewModelWithTimeout = LoginViewModel(authManager: mockAuthManager, timeoutReason: "timeout")
    XCTAssertTrue(viewModelWithTimeout.showTimeoutBanner)
  }

  func testTimeoutBannerHidesWhenOtherReasonProvided() async {
    let viewModelWithOtherReason = LoginViewModel(authManager: mockAuthManager, timeoutReason: "other")
    XCTAssertFalse(viewModelWithOtherReason.showTimeoutBanner)
  }

  func testDismissTimeoutBanner() {
    sut.showTimeoutBanner = true
    sut.dismissTimeoutBanner()
    XCTAssertFalse(sut.showTimeoutBanner)
  }

  // MARK: - Remember Me Tests

  func testRememberMeCachesEmailWhenTrue() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.rememberMe = true
    sut.validateEmail()
    sut.validatePassword()

    await sut.login()

    let cached = UserDefaults.standard.string(forKey: "cachedEmail")
    XCTAssertEqual(cached, "user@example.com")
  }

  func testRememberMeClearsCacheWhenFalse() async {
    UserDefaults.standard.set("old@example.com", forKey: "cachedEmail")
    sut.email = "new@example.com"
    sut.password = "ValidPassword123"
    sut.rememberMe = false
    sut.validateEmail()
    sut.validatePassword()

    await sut.login()

    let cached = UserDefaults.standard.string(forKey: "cachedEmail")
    XCTAssertNil(cached)
  }

  func testLoadsCachedEmailOnInit() async {
    clearUserDefaults()
    UserDefaults.standard.set("cached@example.com", forKey: "cachedEmail")

    let viewModelWithCache = LoginViewModel(authManager: mockAuthManager)

    XCTAssertEqual(viewModelWithCache.email, "cached@example.com")
    XCTAssertTrue(viewModelWithCache.rememberMe)
  }

  // MARK: - Error Mapping Tests

  func testMapErrorHandlesAuthError() {
    let authError = AuthError.invalidCredentials
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Invalid email or password")
  }

  func testMapErrorHandlesUserNotFound() {
    let authError = AuthError.userNotFound
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Email not found. Please sign up first.")
  }

  func testMapErrorHandlesEmailNotVerified() {
    let authError = AuthError.emailNotVerified
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Please verify your email. Check your inbox for a verification link.")
  }

  func testMapErrorHandlesTooManyAttempts() {
    let authError = AuthError.tooManyAttempts(retryAfter: nil)
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Too many login attempts. Please try again later.")
  }

  func testMapErrorHandlesNetworkError() {
    let authError = AuthError.networkError("Connection failed")
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Connection failed")
  }

  func testMapErrorHandlesServerError() {
    let authError = AuthError.serverError("Internal error")
    let mappedError = sut.mapError(authError)
    XCTAssertEqual(mappedError, "Server error. Please try again later.")
  }

  // MARK: - Validation State Tests

  func testValidatingStateSetsDuringEmailValidation() {
    sut.email = "test@example.com"
    XCTAssertFalse(sut.isValidating)

    sut.validateEmail()

    XCTAssertFalse(sut.isValidating, "isValidating should be reset after validation")
  }

  func testValidatingStateSetsDuringPasswordValidation() {
    sut.password = "ValidPassword123"
    XCTAssertFalse(sut.isValidating)

    sut.validatePassword()

    XCTAssertFalse(sut.isValidating, "isValidating should be reset after validation")
  }

  // MARK: - Integration Tests

  func testCompleteLoginFlowWithValidCredentials() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    sut.validateEmail()
    sut.validatePassword()

    XCTAssertTrue(sut.isFormValid)
    XCTAssertFalse(sut.isButtonDisabled)

    await sut.login()

    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(mockAuthManager.isAuthenticated)
  }

  func testCompleteLoginFlowWithInvalidForm() async {
    sut.email = "invalid-email"
    sut.password = "short"

    sut.validateEmail()
    sut.validatePassword()

    XCTAssertFalse(sut.isFormValid)
    XCTAssertTrue(sut.isButtonDisabled)

    await sut.login()

    XCTAssertNotNil(sut.fieldErrors[.email])
    XCTAssertNotNil(sut.fieldErrors[.password])
  }

  func testCompleteLoginFlowWithAuthError() async {
    sut.email = "user@example.com"
    sut.password = "WrongPassword123"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials

    sut.validateEmail()
    sut.validatePassword()

    XCTAssertTrue(sut.isFormValid)

    await sut.login()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(mockAuthManager.isAuthenticated)
  }

  func testMultipleFailedLoginAttempts() async {
    sut.email = "user@example.com"
    sut.password = "WrongPassword"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials

    await sut.login()
    XCTAssertEqual(mockAuthManager.loginCallCount, 1)

    await sut.login()
    XCTAssertEqual(mockAuthManager.loginCallCount, 2)

    XCTAssertNotNil(sut.errorMessage)
  }

  func testClearErrorAndRetry() async {
    sut.email = "user@example.com"
    sut.password = "WrongPassword"
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials

    await sut.login()
    XCTAssertNotNil(sut.errorMessage)

    sut.dismissError()
    XCTAssertNil(sut.errorMessage)

    mockAuthManager.shouldThrowLoginError = false
    await sut.login()

    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(mockAuthManager.isAuthenticated)
  }

  func testRememberMeWithSuccessfulLogin() async {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.rememberMe = true

    await sut.login()

    let cached = UserDefaults.standard.string(forKey: "cachedEmail")
    XCTAssertEqual(cached, "user@example.com")
  }

  func testNoRememberMeWithSuccessfulLogin() async {
    UserDefaults.standard.set("old@example.com", forKey: "cachedEmail")
    sut.email = "new@example.com"
    sut.password = "ValidPassword123"
    sut.rememberMe = false

    await sut.login()

    let cached = UserDefaults.standard.string(forKey: "cachedEmail")
    XCTAssertNil(cached)
  }
}
