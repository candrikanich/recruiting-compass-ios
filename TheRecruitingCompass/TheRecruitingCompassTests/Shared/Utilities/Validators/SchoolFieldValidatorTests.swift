//
//  SchoolFieldValidatorTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 2: Validation System - Unit tests for SchoolFieldValidator
//

import XCTest
@testable import TheRecruitingCompass

final class SchoolFieldValidatorTests: XCTestCase {

  // MARK: - Name Validation Tests

  func testValidateName_whenEmpty_returnsError() {
    // When
    let result = SchoolFieldValidator.validateName("")

    // Then
    XCTAssertEqual(result, "School name is required")
  }

  func testValidateName_whenWhitespaceOnly_returnsError() {
    // When
    let result = SchoolFieldValidator.validateName("   ")

    // Then
    XCTAssertEqual(result, "School name is required")
  }

  func testValidateName_whenOneCharacter_returnsError() {
    // When
    let result = SchoolFieldValidator.validateName("A")

    // Then
    XCTAssertEqual(result, "School name must be at least 2 characters")
  }

  func testValidateName_whenTwoCharacters_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateName("AB")

    // Then
    XCTAssertNil(result)
  }

  func testValidateName_when255Characters_returnsNil() {
    // Given
    let name = String(repeating: "a", count: 255)

    // When
    let result = SchoolFieldValidator.validateName(name)

    // Then
    XCTAssertNil(result)
  }

  func testValidateName_when256Characters_returnsError() {
    // Given
    let name = String(repeating: "a", count: 256)

    // When
    let result = SchoolFieldValidator.validateName(name)

    // Then
    XCTAssertEqual(result, "School name must not exceed 255 characters")
  }

  func testValidateName_whenValidWithWhitespace_trimsAndValidates() {
    // When
    let result = SchoolFieldValidator.validateName("  Harvard  ")

    // Then
    XCTAssertNil(result)
  }

  // MARK: - Location Validation Tests

  func testValidateLocation_whenEmpty_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateLocation("")

    // Then
    XCTAssertNil(result)
  }

  func testValidateLocation_when255Characters_returnsNil() {
    // Given
    let location = String(repeating: "a", count: 255)

    // When
    let result = SchoolFieldValidator.validateLocation(location)

    // Then
    XCTAssertNil(result)
  }

  func testValidateLocation_when256Characters_returnsError() {
    // Given
    let location = String(repeating: "a", count: 256)

    // When
    let result = SchoolFieldValidator.validateLocation(location)

    // Then
    XCTAssertEqual(result, "Location must not exceed 255 characters")
  }

  func testValidateLocation_whenValid_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateLocation("Cambridge, MA")

    // Then
    XCTAssertNil(result)
  }

  // MARK: - City Validation Tests

  func testValidateCity_whenEmpty_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateCity("")

    // Then
    XCTAssertNil(result)
  }

  func testValidateCity_when100Characters_returnsNil() {
    // Given
    let city = String(repeating: "a", count: 100)

    // When
    let result = SchoolFieldValidator.validateCity(city)

    // Then
    XCTAssertNil(result)
  }

  func testValidateCity_when101Characters_returnsError() {
    // Given
    let city = String(repeating: "a", count: 101)

    // When
    let result = SchoolFieldValidator.validateCity(city)

    // Then
    XCTAssertEqual(result, "City must not exceed 100 characters")
  }

  // MARK: - State Validation Tests

  func testValidateState_whenEmpty_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateState("")

    // Then
    XCTAssertNil(result)
  }

  func testValidateState_when100Characters_returnsNil() {
    // Given
    let state = String(repeating: "a", count: 100)

    // When
    let result = SchoolFieldValidator.validateState(state)

    // Then
    XCTAssertNil(result)
  }

  func testValidateState_when101Characters_returnsError() {
    // Given
    let state = String(repeating: "a", count: 101)

    // When
    let result = SchoolFieldValidator.validateState(state)

    // Then
    XCTAssertEqual(result, "State must not exceed 100 characters")
  }

  // MARK: - Conference Validation Tests

  func testValidateConference_whenEmpty_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateConference("")

    // Then
    XCTAssertNil(result)
  }

  func testValidateConference_when100Characters_returnsNil() {
    // Given
    let conference = String(repeating: "a", count: 100)

    // When
    let result = SchoolFieldValidator.validateConference(conference)

    // Then
    XCTAssertNil(result)
  }

  func testValidateConference_when101Characters_returnsError() {
    // Given
    let conference = String(repeating: "a", count: 101)

    // When
    let result = SchoolFieldValidator.validateConference(conference)

    // Then
    XCTAssertEqual(result, "Conference must not exceed 100 characters")
  }

  func testValidateConference_whenValid_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateConference("Pac-12")

    // Then
    XCTAssertNil(result)
  }

  // MARK: - Website Validation Tests

  func testValidateWebsite_whenEmpty_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenWhitespaceOnly_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("   ")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenValidHTTP_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("http://stanford.edu")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenValidHTTPS_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("https://stanford.edu")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenValidWithPath_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("https://stanford.edu/athletics/baseball")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenValidWithQuery_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("https://stanford.edu?page=athletics")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenNoProtocol_returnsNil() {
    // Bare domains are accepted and normalized at display time
    // When
    let result = SchoolFieldValidator.validateWebsite("stanford.edu")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenBaredomainWithPath_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("jcu.edu/")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenBaredomainWithSubpath_returnsNil() {
    // When
    let result = SchoolFieldValidator.validateWebsite("jcu.edu/athletics/baseball")

    // Then
    XCTAssertNil(result)
  }

  func testValidateWebsite_whenInvalidProtocol_returnsError() {
    // When
    let result = SchoolFieldValidator.validateWebsite("ftp://stanford.edu")

    // Then
    XCTAssertEqual(result, "Please enter a valid website (e.g. jcu.edu or https://jcu.edu)")
  }

  func testValidateWebsite_when501Characters_returnsError() {
    // Given
    let longUrl = "https://example.com/" + String(repeating: "a", count: 481)

    // When
    let result = SchoolFieldValidator.validateWebsite(longUrl)

    // Then
    XCTAssertEqual(result, "Website URL must not exceed 500 characters")
  }

  func testValidateWebsite_whenValidWithWhitespace_trimsAndValidates() {
    // When
    let result = SchoolFieldValidator.validateWebsite("  https://stanford.edu  ")

    // Then
    XCTAssertNil(result)
  }

  // MARK: - Delegation Tests

  func testValidateTwitterHandle_delegatesToFieldValidator() {
    // When
    let validResult = SchoolFieldValidator.validateTwitterHandle("Stanford")
    let invalidResult = SchoolFieldValidator.validateTwitterHandle("@123456789012345678901")

    // Then
    XCTAssertNil(validResult)
    XCTAssertNotNil(invalidResult)
  }

  func testValidateInstagramHandle_delegatesToFieldValidator() {
    // When
    let validResult = SchoolFieldValidator.validateInstagramHandle("stanford")
    let invalidResult = SchoolFieldValidator.validateInstagramHandle("@" + String(repeating: "a", count: 31))

    // Then
    XCTAssertNil(validResult)
    XCTAssertNotNil(invalidResult)
  }

  func testValidateNotes_delegatesToFieldValidator() {
    // When
    let validResult = SchoolFieldValidator.validateNotes("Great school")
    let invalidResult = SchoolFieldValidator.validateNotes(String(repeating: "a", count: 5001))

    // Then
    XCTAssertNil(validResult)
    XCTAssertNotNil(invalidResult)
  }
}
