//
//  CoachFormStateTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Unit tests for CoachFormState
//

import XCTest
@testable import TheRecruitingCompass

final class CoachFormStateTests: XCTestCase {

  // MARK: - Initialization Tests

  func testDefaultInitialization() {
    // When
    let formState = CoachFormState()

    // Then
    XCTAssertNil(formState.selectedSchoolId)
    XCTAssertNil(formState.role)
    XCTAssertEqual(formState.firstName, "")
    XCTAssertEqual(formState.lastName, "")
    XCTAssertEqual(formState.email, "")
    XCTAssertEqual(formState.phone, "")
    XCTAssertEqual(formState.twitterHandle, "")
    XCTAssertEqual(formState.instagramHandle, "")
    XCTAssertEqual(formState.notes, "")
  }

  // MARK: - isSchoolSelected Tests

  func testIsSchoolSelected_whenNil_returnsFalse() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = nil

    // Then
    XCTAssertFalse(formState.isSchoolSelected)
  }

  func testIsSchoolSelected_whenNotNil_returnsTrue() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"

    // Then
    XCTAssertTrue(formState.isSchoolSelected)
  }

  // MARK: - isSubmittable Tests

  func testIsSubmittable_whenAllRequiredFieldsEmpty_returnsFalse() {
    // Given
    let formState = CoachFormState()

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenSchoolIdMissing_returnsFalse() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "John"
    formState.lastName = "Smith"

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenRoleMissing_returnsFalse() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"
    formState.firstName = "John"
    formState.lastName = "Smith"

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenFirstNameEmpty_returnsFalse() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"
    formState.role = .head
    formState.lastName = "Smith"

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenLastNameEmpty_returnsFalse() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"
    formState.role = .head
    formState.firstName = "John"

    // Then
    XCTAssertFalse(formState.isSubmittable)
  }

  func testIsSubmittable_whenAllRequiredFieldsFilled_returnsTrue() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"
    formState.role = .head
    formState.firstName = "John"
    formState.lastName = "Smith"

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }

  func testIsSubmittable_withOptionalFieldsFilled_returnsTrue() {
    // Given
    var formState = CoachFormState()
    formState.selectedSchoolId = "school-123"
    formState.role = .assistant
    formState.firstName = "Jane"
    formState.lastName = "Doe"
    formState.email = "jane@example.com"
    formState.phone = "555-1234"
    formState.twitterHandle = "@janedoe"
    formState.instagramHandle = "@janedoe"
    formState.notes = "Great coach"

    // Then
    XCTAssertTrue(formState.isSubmittable)
  }
}
