import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SignupViewModelTests: XCTestCase {
  var sut: SignupViewModel!

  @MainActor
  override func setUp() {
    super.setUp()
    sut = SignupViewModel()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
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
    sut.selectRole(.student)
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
    sut.selectedRole = .student
    sut.familyCode = "FAM-ABC12345"
    sut.validateFamilyCode()

    XCTAssertNil(sut.fieldErrors[.familyCode])
  }

  func testValidateFamilyCodeOptionalForStudentRole() {
    sut.selectedRole = .student
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
    sut.selectedRole = .parent
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForStudentRoleWithoutFamilyCode() {
    sut.selectedRole = .student
    sut.fullName = "Jane Doe"
    sut.email = "jane@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.familyCode = ""
    sut.termsAccepted = true

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidForStudentRoleWithFamilyCode() {
    sut.selectedRole = .student
    sut.fullName = "Jane Doe"
    sut.email = "jane@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.familyCode = "FAM-ABC12345"
    sut.termsAccepted = true

    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormInvalidWhenPasswordsDoNotMatch() {
    sut.selectedRole = .parent
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "DifferentPass123"
    sut.termsAccepted = true

    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWhenTermsNotAccepted() {
    sut.selectedRole = .parent
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
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
    sut.selectedRole = .parent
    sut.fullName = "John Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true
    sut.fieldErrors[.email] = "Invalid email"

    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - Error Handling Tests

  func testDismissError() {
    sut.errorMessage = "Test error"
    sut.dismissError()

    XCTAssertNil(sut.errorMessage)
  }
}
