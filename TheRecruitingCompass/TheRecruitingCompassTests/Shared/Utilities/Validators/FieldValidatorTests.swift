//
//  FieldValidatorTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Unit tests for FieldValidator
//

import XCTest
@testable import TheRecruitingCompass

final class FieldValidatorTests: XCTestCase {

  // MARK: - Role Validation Tests

  func testValidateRole_whenNil_returnsError() {
    // When
    let error = FieldValidator.validateRole(nil)

    // Then
    XCTAssertEqual(error, "Please select a role")
  }

  func testValidateRole_whenNotNil_returnsNil() {
    // When
    let error = FieldValidator.validateRole("head")

    // Then
    XCTAssertNil(error)
  }

  // MARK: - First Name Validation Tests

  func testValidateFirstName_whenEmpty_returnsError() {
    // When
    let error = FieldValidator.validateFirstName("")

    // Then
    XCTAssertEqual(error, "First name is required")
  }

  func testValidateFirstName_whenWhitespaceOnly_returnsError() {
    // When
    let error = FieldValidator.validateFirstName("   ")

    // Then
    XCTAssertEqual(error, "First name is required")
  }

  func testValidateFirstName_whenValid_returnsNil() {
    // When
    let error = FieldValidator.validateFirstName("John")

    // Then
    XCTAssertNil(error)
  }

  func testValidateFirstName_whenTooLong_returnsError() {
    // Given
    let longName = String(repeating: "a", count: 101)

    // When
    let error = FieldValidator.validateFirstName(longName)

    // Then
    XCTAssertEqual(error, "First name must not exceed 100 characters")
  }

  func testValidateFirstName_whenExactly100Chars_returnsNil() {
    // Given
    let name = String(repeating: "a", count: 100)

    // When
    let error = FieldValidator.validateFirstName(name)

    // Then
    XCTAssertNil(error)
  }

  // MARK: - Last Name Validation Tests

  func testValidateLastName_whenEmpty_returnsError() {
    // When
    let error = FieldValidator.validateLastName("")

    // Then
    XCTAssertEqual(error, "Last name is required")
  }

  func testValidateLastName_whenWhitespaceOnly_returnsError() {
    // When
    let error = FieldValidator.validateLastName("   ")

    // Then
    XCTAssertEqual(error, "Last name is required")
  }

  func testValidateLastName_whenValid_returnsNil() {
    // When
    let error = FieldValidator.validateLastName("Smith")

    // Then
    XCTAssertNil(error)
  }

  func testValidateLastName_whenTooLong_returnsError() {
    // Given
    let longName = String(repeating: "a", count: 101)

    // When
    let error = FieldValidator.validateLastName(longName)

    // Then
    XCTAssertEqual(error, "Last name must not exceed 100 characters")
  }

  // MARK: - Email Validation Tests

  func testValidateEmail_whenEmpty_returnsNil() {
    // When
    let error = FieldValidator.validateEmail("")

    // Then
    XCTAssertNil(error) // Empty is valid (optional field)
  }

  func testValidateEmail_whenValidEmail_returnsNil() {
    // When
    let error = FieldValidator.validateEmail("test@example.com")

    // Then
    XCTAssertNil(error)
  }

  func testValidateEmail_whenTooShort_returnsError() {
    // When
    let error = FieldValidator.validateEmail("a@b")

    // Then
    XCTAssertEqual(error, "Email must be at least 5 characters")
  }

  func testValidateEmail_whenTooLong_returnsError() {
    // Given
    let longEmail = String(repeating: "a", count: 240) + "@example.com"

    // When
    let error = FieldValidator.validateEmail(longEmail)

    // Then
    XCTAssertEqual(error, "Email must not exceed 255 characters")
  }

  func testValidateEmail_whenInvalidFormat_returnsError() {
    // Given
    let invalidEmails = [
      "notanemail",
      "@example.com",
      "test@",
      "test@.com",
      "test..test@example.com",
      "test@example"
    ]

    // When/Then
    for email in invalidEmails {
      let error = FieldValidator.validateEmail(email)
      XCTAssertEqual(error, "Please enter a valid email address", "Failed for: \(email)")
    }
  }

  // MARK: - Phone Validation Tests

  func testValidatePhone_whenEmpty_returnsNil() {
    // When
    let error = FieldValidator.validatePhone("")

    // Then
    XCTAssertNil(error) // Empty is valid (optional field)
  }

  func testValidatePhone_whenValidFormats_returnsNil() {
    // Given
    let validPhones = [
      "(555) 123-4567",
      "555-123-4567",
      "555.123.4567",
      "5551234567"
    ]

    // When/Then
    for phone in validPhones {
      let error = FieldValidator.validatePhone(phone)
      XCTAssertNil(error, "Failed for: \(phone)")
    }
  }

  func testValidatePhone_whenInvalidFormat_returnsError() {
    // Given
    let invalidPhones = [
      "123",
      "123-456",
      "abc-def-ghij",
      "555-12-34567"
    ]

    // When/Then
    for phone in invalidPhones {
      let error = FieldValidator.validatePhone(phone)
      XCTAssertEqual(error, "Please enter a valid phone number", "Failed for: \(phone)")
    }
  }

  // MARK: - Twitter Handle Validation Tests

  func testValidateTwitterHandle_whenEmpty_returnsNil() {
    // When
    let error = FieldValidator.validateTwitterHandle("")

    // Then
    XCTAssertNil(error) // Empty is valid (optional field)
  }

  func testValidateTwitterHandle_whenValid_returnsNil() {
    // Given
    let validHandles = [
      "johndoe",
      "jane_smith",
      "coach123",
      "a"
    ]

    // When/Then
    for handle in validHandles {
      let error = FieldValidator.validateTwitterHandle(handle)
      XCTAssertNil(error, "Failed for: \(handle)")
    }
  }

  func testValidateTwitterHandle_withAtSign_returnsNil() {
    // When
    let error = FieldValidator.validateTwitterHandle("@johndoe")

    // Then
    XCTAssertNil(error) // Should strip @ and validate
  }

  func testValidateTwitterHandle_whenTooLong_returnsError() {
    // Given
    let longHandle = String(repeating: "a", count: 16)

    // When
    let error = FieldValidator.validateTwitterHandle(longHandle)

    // Then
    XCTAssertNotNil(error)
    XCTAssertTrue(error!.contains("1-15 characters"))
  }

  func testValidateTwitterHandle_withInvalidChars_returnsError() {
    // Given
    let invalidHandles = [
      "john-doe",
      "john.smith",
      "john doe",
      "john@smith"
    ]

    // When/Then
    for handle in invalidHandles {
      let error = FieldValidator.validateTwitterHandle(handle)
      XCTAssertNotNil(error, "Failed for: \(handle)")
    }
  }

  // MARK: - Instagram Handle Validation Tests

  func testValidateInstagramHandle_whenEmpty_returnsNil() {
    // When
    let error = FieldValidator.validateInstagramHandle("")

    // Then
    XCTAssertNil(error) // Empty is valid (optional field)
  }

  func testValidateInstagramHandle_whenValid_returnsNil() {
    // Given
    let validHandles = [
      "johndoe",
      "jane_smith",
      "coach.123",
      "john.doe",
      "a"
    ]

    // When/Then
    for handle in validHandles {
      let error = FieldValidator.validateInstagramHandle(handle)
      XCTAssertNil(error, "Failed for: \(handle)")
    }
  }

  func testValidateInstagramHandle_withAtSign_returnsNil() {
    // When
    let error = FieldValidator.validateInstagramHandle("@johndoe")

    // Then
    XCTAssertNil(error) // Should strip @ and validate
  }

  func testValidateInstagramHandle_whenTooLong_returnsError() {
    // Given
    let longHandle = String(repeating: "a", count: 31)

    // When
    let error = FieldValidator.validateInstagramHandle(longHandle)

    // Then
    XCTAssertNotNil(error)
    XCTAssertTrue(error!.contains("1-30 characters"))
  }

  func testValidateInstagramHandle_withInvalidChars_returnsError() {
    // Given
    let invalidHandles = [
      "john-doe",
      "john doe",
      "john@smith"
    ]

    // When/Then
    for handle in invalidHandles {
      let error = FieldValidator.validateInstagramHandle(handle)
      XCTAssertNotNil(error, "Failed for: \(handle)")
    }
  }

  // MARK: - Notes Validation Tests

  func testValidateNotes_whenEmpty_returnsNil() {
    // When
    let error = FieldValidator.validateNotes("")

    // Then
    XCTAssertNil(error) // Empty is valid (optional field)
  }

  func testValidateNotes_whenValid_returnsNil() {
    // Given
    let notes = "This is a valid note about the coach."

    // When
    let error = FieldValidator.validateNotes(notes)

    // Then
    XCTAssertNil(error)
  }

  func testValidateNotes_whenTooLong_returnsError() {
    // Given
    let longNotes = String(repeating: "a", count: 5001)

    // When
    let error = FieldValidator.validateNotes(longNotes)

    // Then
    XCTAssertEqual(error, "Notes must not exceed 5000 characters")
  }

  func testValidateNotes_whenExactly5000Chars_returnsNil() {
    // Given
    let notes = String(repeating: "a", count: 5000)

    // When
    let error = FieldValidator.validateNotes(notes)

    // Then
    XCTAssertNil(error)
  }
}
