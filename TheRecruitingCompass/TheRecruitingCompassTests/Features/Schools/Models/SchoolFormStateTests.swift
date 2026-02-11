//
//  SchoolFormStateTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 1: Core Models - Unit tests for SchoolFormState
//

import XCTest
@testable import TheRecruitingCompass

final class SchoolFormStateTests: XCTestCase {

  // MARK: - Initialization Tests

  func testDefaultInitialization() {
    // When
    let formState = SchoolFormState()

    // Then
    XCTAssertEqual(formState.name, "")
    XCTAssertEqual(formState.location, "")
    XCTAssertEqual(formState.city, "")
    XCTAssertEqual(formState.state, "")
    XCTAssertNil(formState.division)
    XCTAssertEqual(formState.conference, "")
    XCTAssertEqual(formState.website, "")
    XCTAssertEqual(formState.twitterHandle, "")
    XCTAssertEqual(formState.instagramHandle, "")
    XCTAssertEqual(formState.notes, "")
    XCTAssertEqual(formState.status, .interested)
    XCTAssertTrue(formState.isAutocompleteEnabled)
  }

  func testCustomInitialization() {
    // When
    let formState = SchoolFormState(
      name: "Harvard University",
      location: "Cambridge, MA",
      division: .d1,
      status: .contacted,
      isAutocompleteEnabled: false
    )

    // Then
    XCTAssertEqual(formState.name, "Harvard University")
    XCTAssertEqual(formState.location, "Cambridge, MA")
    XCTAssertEqual(formState.division, .d1)
    XCTAssertEqual(formState.status, .contacted)
    XCTAssertFalse(formState.isAutocompleteEnabled)
  }

  // MARK: - isSubmittable Tests

  func testIsSubmittable_whenNameEmpty_returnsFalse() {
    // Given
    var formState = SchoolFormState()
    formState.name = ""

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameOnlyWhitespace_returnsFalse() {
    // Given
    var formState = SchoolFormState()
    formState.name = "   "

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameOneCharacter_returnsFalse() {
    // Given
    var formState = SchoolFormState()
    formState.name = "A"

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameTwoCharacters_returnsTrue() {
    // Given
    var formState = SchoolFormState()
    formState.name = "AB"

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameThreeCharacters_returnsTrue() {
    // Given
    var formState = SchoolFormState()
    formState.name = "ABC"

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameWithLeadingWhitespace_trimsAndValidates() {
    // Given
    var formState = SchoolFormState()
    formState.name = "  AB"

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameWithTrailingWhitespace_trimsAndValidates() {
    // Given
    var formState = SchoolFormState()
    formState.name = "AB  "

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  func testIsSubmittable_whenNameWithSurroundingWhitespace_trimsAndValidates() {
    // Given
    var formState = SchoolFormState()
    formState.name = "  A  "

    // Then
    XCTAssertFalse(formState.isSubmittable) // Only 1 char after trim
  }

  func testIsSubmittable_whenAllFieldsFilled_returnsTrue() {
    // Given
    var formState = SchoolFormState()
    formState.name = "Stanford University"
    formState.location = "Stanford, CA"
    formState.city = "Stanford"
    formState.state = "CA"
    formState.division = .d1
    formState.conference = "Pac-12"
    formState.website = "https://stanford.edu"
    formState.twitterHandle = "@Stanford"
    formState.instagramHandle = "@stanford"
    formState.notes = "Great academic school"
    formState.status = .recruited

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  // MARK: - autoFilledFields Tests

  func testAutoFilledFields_mvpReturnsEmpty() {
    // Given
    let formState = SchoolFormState()

    // Then
    XCTAssertEqual(formState.autoFilledFields, [])
  }

  // MARK: - Constants Tests

  func testNotesCharacterLimit() {
    // Then
    XCTAssertEqual(SchoolFormState.notesCharacterLimit, 5000)
  }

  func testNameMinimumLength() {
    // Then
    XCTAssertEqual(SchoolFormState.nameMinimumLength, 2)
  }
}
