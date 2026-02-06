import XCTest
@testable import TheRecruitingCompass

@MainActor
final class LoginViewModelTests: XCTestCase {
  var sut: LoginViewModel!
  var mockAuthManager: AuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = AuthManager()
    sut = LoginViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  func testLoginViewModelInitialState() {
    XCTAssertEqual(sut.email, "")
    XCTAssertEqual(sut.password, "")
    XCTAssertFalse(sut.rememberMe)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssert(sut.fieldErrors.isEmpty)
  }

  func testValidateEmailOnBlur() {
    sut.email = "invalid"
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors["email"])
  }

  func testValidatePasswordOnBlur() {
    sut.password = "short"
    sut.validatePassword()
    XCTAssertNotNil(sut.fieldErrors["password"])
  }

  func testIsFormValidWhenFieldsValid() {
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"
    sut.validateEmail()
    sut.validatePassword()
    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidWhenFieldsInvalid() {
    sut.email = "invalid"
    sut.password = "short"
    sut.validateEmail()
    sut.validatePassword()
    XCTAssertFalse(sut.isFormValid)
  }
}
