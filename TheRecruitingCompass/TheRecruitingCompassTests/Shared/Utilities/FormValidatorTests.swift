import XCTest
@testable import TheRecruitingCompass

final class FormValidatorTests: XCTestCase {
  func testValidateEmailWithValidEmail() {
    let result = FormValidator.validateEmail("user@example.com")
    XCTAssertNil(result, "Valid email should not return error")
  }

  func testValidateEmailWithInvalidEmail() {
    let result = FormValidator.validateEmail("notanemail")
    XCTAssertNotNil(result, "Invalid email should return error")
  }

  func testValidateEmailWithEmptyString() {
    let result = FormValidator.validateEmail("")
    XCTAssertNotNil(result, "Empty email should return error")
  }

  func testValidateEmailWithWhitespace() {
    let result = FormValidator.validateEmail("   user@example.com   ")
    XCTAssertNil(result, "Email with whitespace should be trimmed and valid")
  }

  func testValidatePasswordWithValidPassword() {
    let result = FormValidator.validatePassword("ValidPassword123")
    XCTAssertNil(result, "Valid password should not return error")
  }

  func testValidatePasswordWithShortPassword() {
    let result = FormValidator.validatePassword("short")
    XCTAssertNotNil(result, "Short password should return error")
  }

  func testValidatePasswordMinimumLength() {
    let result = FormValidator.validatePassword("12345678")
    XCTAssertNil(result, "Password with 8 characters should be valid")
  }

  func testValidatePasswordWithEmptyString() {
    let result = FormValidator.validatePassword("")
    XCTAssertNotNil(result, "Empty password should return error")
  }

  // MARK: - Name Validation Tests

  func testValidateNameWithValidName() {
    let result = FormValidator.validateName("John Doe")
    XCTAssertNil(result)
  }

  func testValidateNameWithSingleCharacterName() {
    let result = FormValidator.validateName("J")
    XCTAssertEqual(result, "Name must be at least 2 characters")
  }

  func testValidateNameWithEmptyName() {
    let result = FormValidator.validateName("")
    XCTAssertEqual(result, "Name is required")
  }

  func testValidateNameWithNumbers() {
    let result = FormValidator.validateName("John123")
    XCTAssertEqual(result, "Name can only contain letters, spaces, hyphens, and apostrophes")
  }

  func testValidateNameWithValidCharacters() {
    let result = FormValidator.validateName("Mary-Jane O'Connor")
    XCTAssertNil(result)
  }

  // MARK: - Password Strength Validation Tests

  func testValidatePasswordStrengthWithWeakPassword() {
    let result = FormValidator.validatePasswordStrength("weak")
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains("at least 8 characters"))
    XCTAssertTrue(result.errors.contains("an uppercase letter"))
    XCTAssertTrue(result.errors.contains("a number"))
  }

  func testValidatePasswordStrengthWithStrongPassword() {
    let result = FormValidator.validatePasswordStrength("StrongPass123")
    XCTAssertTrue(result.isValid)
    XCTAssertTrue(result.errors.isEmpty)
  }

  func testValidatePasswordStrengthMissingUppercase() {
    let result = FormValidator.validatePasswordStrength("lowercase123")
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains("an uppercase letter"))
  }

  func testValidatePasswordStrengthMissingLowercase() {
    let result = FormValidator.validatePasswordStrength("UPPERCASE123")
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains("a lowercase letter"))
  }

  func testValidatePasswordStrengthMissingNumber() {
    let result = FormValidator.validatePasswordStrength("NoNumbers")
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains("a number"))
  }

  // MARK: - Password Match Validation Tests

  func testValidatePasswordMatchWhenMatching() {
    let result = FormValidator.validatePasswordMatch("Password123", "Password123")
    XCTAssertNil(result)
  }

  func testValidatePasswordMatchWhenNotMatching() {
    let result = FormValidator.validatePasswordMatch("Password123", "Password124")
    XCTAssertEqual(result, "Passwords do not match")
  }

  // MARK: - Family Code Validation Tests

  func testValidateFamilyCodeWithValidFormat() {
    let result = FormValidator.validateFamilyCode("FAM-ABC123")
    XCTAssertNil(result)
  }

  func testValidateFamilyCodeWithInvalidFormat() {
    let result = FormValidator.validateFamilyCode("INVALID-CODE")
    XCTAssertEqual(result, "Family code must be in format FAM-XXXXXX")
  }

  func testValidateFamilyCodeWithNil() {
    let result = FormValidator.validateFamilyCode(nil)
    XCTAssertNil(result)
  }

  func testValidateFamilyCodeWithEmptyString() {
    let result = FormValidator.validateFamilyCode("")
    XCTAssertNil(result)
  }

  func testValidateFamilyCodeWithTooShort() {
    let result = FormValidator.validateFamilyCode("FAM-ABC")
    XCTAssertEqual(result, "Family code must be in format FAM-XXXXXX")
  }

  func testValidateFamilyCodeWithTooLong() {
    let result = FormValidator.validateFamilyCode("FAM-ABC12345")
    XCTAssertEqual(result, "Family code must be in format FAM-XXXXXX")
  }
}
