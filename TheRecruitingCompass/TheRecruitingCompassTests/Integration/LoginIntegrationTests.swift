import XCTest
@testable import TheRecruitingCompass

final class LoginIntegrationTests: XCTestCase {
  var authManager: AuthManager!
  var loginViewModel: LoginViewModel!

  @MainActor
  override func setUp() {
    super.setUp()
    try? KeychainHelper.shared.delete(forKey: "cachedEmail")
    authManager = AuthManager()
    loginViewModel = LoginViewModel(authManager: authManager)
  }

  @MainActor
  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: "cachedEmail")
    authManager = nil
    loginViewModel = nil
    super.tearDown()
  }

  @MainActor
  func testLoginFlowWithValidCredentials() async {
    // Arrange
    loginViewModel.email = "test@example.com"
    loginViewModel.password = "ValidPassword123"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()

    // Assert form is valid
    XCTAssertTrue(loginViewModel.isFormValid)
    XCTAssertNil(loginViewModel.fieldErrors[.email])
    XCTAssertNil(loginViewModel.fieldErrors[.password])
  }

  @MainActor
  func testFormValidationErrorsPreventsSubmission() async {
    // Arrange
    loginViewModel.email = "invalid"
    loginViewModel.password = "short"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()

    // Assert
    XCTAssertFalse(loginViewModel.isFormValid)
    XCTAssertNotNil(loginViewModel.fieldErrors[.email])
    XCTAssertNotNil(loginViewModel.fieldErrors[.password])
  }

  @MainActor
  func testRememberMeCheckboxToggle() {
    // Arrange
    XCTAssertFalse(loginViewModel.rememberMe)

    // Act
    loginViewModel.rememberMe.toggle()

    // Assert
    XCTAssertTrue(loginViewModel.rememberMe)
  }

  @MainActor
  func testEmailValidationWhenEmpty() async {
    // Arrange
    loginViewModel.email = ""

    // Act
    loginViewModel.validateEmail()

    // Assert
    XCTAssertNotNil(loginViewModel.fieldErrors[.email])
    XCTAssertEqual(loginViewModel.fieldErrors[.email], "Email is required")
  }

  @MainActor
  func testPasswordValidationWhenEmpty() async {
    // Arrange
    loginViewModel.password = ""

    // Act
    loginViewModel.validatePassword()

    // Assert
    XCTAssertNotNil(loginViewModel.fieldErrors[.password])
    XCTAssertEqual(loginViewModel.fieldErrors[.password], "Password is required")
  }

  @MainActor
  func testPasswordValidationWhenTooShort() async {
    // Arrange
    loginViewModel.password = "Pass123"

    // Act
    loginViewModel.validatePassword()

    // Assert
    XCTAssertNotNil(loginViewModel.fieldErrors[.password])
    XCTAssertEqual(loginViewModel.fieldErrors[.password], "Password must be at least 8 characters")
  }

  @MainActor
  func testFormValidityUpdatesAfterValidation() async {
    // Arrange - start with invalid data and add errors manually
    loginViewModel.email = "test@example.com"
    loginViewModel.password = "ValidPassword123"
    loginViewModel.fieldErrors[.email] = "Invalid email"

    // Assert - form is invalid due to field errors
    XCTAssertFalse(loginViewModel.isFormValid)

    // Act - validate fields (clears the errors)
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()

    // Assert - form should now be valid
    XCTAssertTrue(loginViewModel.isFormValid)
  }

  @MainActor
  func testButtonDisabledWhenFormInvalid() async {
    // Arrange
    loginViewModel.email = "invalid"
    loginViewModel.password = "short"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()
    loginViewModel.isLoading = false

    // Assert
    XCTAssertTrue(loginViewModel.isButtonDisabled)
  }

  @MainActor
  func testButtonEnabledWhenFormValid() async {
    // Arrange
    loginViewModel.email = "test@example.com"
    loginViewModel.password = "ValidPassword123"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()
    loginViewModel.isLoading = false

    // Assert
    XCTAssertFalse(loginViewModel.isButtonDisabled)
  }

  @MainActor
  func testButtonDisabledWhileLoading() async {
    // Arrange
    loginViewModel.email = "test@example.com"
    loginViewModel.password = "ValidPassword123"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()

    // Act
    loginViewModel.isLoading = true

    // Assert
    XCTAssertTrue(loginViewModel.isButtonDisabled)
  }

  @MainActor
  func testErrorMessageClearsOnDismissal() async {
    // Arrange
    loginViewModel.errorMessage = "Test error message"

    // Act
    loginViewModel.dismissError()

    // Assert
    XCTAssertNil(loginViewModel.errorMessage)
  }

  @MainActor
  func testTimeoutBannerDismissal() async {
    // Arrange
    loginViewModel.showTimeoutBanner = true

    // Act
    loginViewModel.dismissTimeoutBanner()

    // Assert
    XCTAssertFalse(loginViewModel.showTimeoutBanner)
  }

  @MainActor
  func testFieldErrorsClearedAfterSuccessfulValidation() async {
    // Arrange - start with invalid data
    loginViewModel.email = "invalid"
    loginViewModel.password = "short"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()
    XCTAssertNotNil(loginViewModel.fieldErrors[.email])
    XCTAssertNotNil(loginViewModel.fieldErrors[.password])

    // Act - correct the data and validate again
    loginViewModel.email = "valid@example.com"
    loginViewModel.password = "ValidPassword123"
    loginViewModel.validateEmail()
    loginViewModel.validatePassword()

    // Assert
    XCTAssertNil(loginViewModel.fieldErrors[.email])
    XCTAssertNil(loginViewModel.fieldErrors[.password])
  }

  @MainActor
  func testWhitespaceOnlyEmailIsInvalid() async {
    // Arrange
    loginViewModel.email = "   "

    // Act
    loginViewModel.validateEmail()

    // Assert
    XCTAssertNotNil(loginViewModel.fieldErrors[.email])
  }

  @MainActor
  func testValidEmailFormats() async {
    // Test multiple valid email formats
    let validEmails = [
      "user@example.com",
      "test.email@example.co.uk",
      "user+tag@example.com",
      "user_name@example.com",
      "123@example.com"
    ]

    for email in validEmails {
      loginViewModel.email = email
      loginViewModel.validateEmail()
      XCTAssertNil(loginViewModel.fieldErrors[.email], "Email '\(email)' should be valid")
    }
  }

  @MainActor
  func testInvalidEmailFormats() async {
    // Test multiple invalid email formats
    let invalidEmails = [
      "notanemail",
      "@example.com",
      "user@",
      "user name@example.com",
      "user@.com"
    ]

    for email in invalidEmails {
      loginViewModel.email = email
      loginViewModel.validateEmail()
      XCTAssertNotNil(loginViewModel.fieldErrors[.email], "Email '\(email)' should be invalid")
    }
  }
}
