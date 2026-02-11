//
//  CoachCreateRequest+PreparationTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - CoachCreateRequest preparation tests
//

import XCTest
@testable import TheRecruitingCompass

final class CoachCreateRequestPreparationTests: XCTestCase {

  // MARK: - Initialization Tests

  func testFrom_withAllFields_createsRequestCorrectly() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = " John "
    formState.lastName = " Smith "
    formState.email = " JOHN.SMITH@EXAMPLE.COM "
    formState.phone = "(555) 123-4567"
    formState.twitterHandle = "@coachsmith"
    formState.instagramHandle = "@coach.smith"
    formState.notes = "<p>Great coach</p>"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school-123",
      userId: "user-456",
      familyUnitId: "family-789"
    )

    // Then
    XCTAssertEqual(request.schoolId, "school-123")
    XCTAssertEqual(request.userId, "user-456")
    XCTAssertEqual(request.familyUnitId, "family-789")
    XCTAssertEqual(request.role, "head")
    XCTAssertEqual(request.firstName, "John")
    XCTAssertEqual(request.lastName, "Smith")
    XCTAssertEqual(request.email, "john.smith@example.com")
    XCTAssertEqual(request.phone, "(555) 123-4567")
    XCTAssertEqual(request.twitterHandle, "coachsmith")
    XCTAssertEqual(request.instagramHandle, "coach.smith")
    XCTAssertEqual(request.notes, "Great coach")
  }

  func testFrom_withRequiredFieldsOnly_createsRequestCorrectly() {
    // Given
    var formState = CoachFormState()
    formState.role = .assistant
    formState.firstName = "Jane"
    formState.lastName = "Doe"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school-abc",
      userId: "user-xyz",
      familyUnitId: "family-123"
    )

    // Then
    XCTAssertEqual(request.schoolId, "school-abc")
    XCTAssertEqual(request.userId, "user-xyz")
    XCTAssertEqual(request.familyUnitId, "family-123")
    XCTAssertEqual(request.role, "assistant")
    XCTAssertEqual(request.firstName, "Jane")
    XCTAssertEqual(request.lastName, "Doe")
    XCTAssertNil(request.email)
    XCTAssertNil(request.phone)
    XCTAssertNil(request.twitterHandle)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.notes)
  }

  func testFrom_withMixedRequiredAndOptional_createsRequestCorrectly() {
    // Given
    var formState = CoachFormState()
    formState.role = .recruiting
    formState.firstName = "Bob"
    formState.lastName = "Johnson"
    formState.email = "bob@example.com"
    formState.twitterHandle = "@bobjohnson"
    // Leave phone, instagram, notes empty

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school-1",
      userId: "user-1",
      familyUnitId: "family-1"
    )

    // Then
    XCTAssertEqual(request.role, "recruiting")
    XCTAssertEqual(request.firstName, "Bob")
    XCTAssertEqual(request.lastName, "Johnson")
    XCTAssertEqual(request.email, "bob@example.com")
    XCTAssertEqual(request.twitterHandle, "bobjohnson")
    XCTAssertNil(request.phone)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.notes)
  }

  // MARK: - Field Transformation Tests

  func testFrom_emailIsLowercasedAndTrimmed() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.email = "   UPPERCASE@EXAMPLE.COM   "

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.email, "uppercase@example.com")
  }

  func testFrom_emptyEmailConvertsToNil() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.email = ""

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.email)
  }

  func testFrom_emptyPhoneConvertsToNil() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.phone = ""

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.phone)
  }

  func testFrom_twitterHandleStripsLeadingAt() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.twitterHandle = "@testuser"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.twitterHandle, "testuser")
  }

  func testFrom_instagramHandleStripsLeadingAt() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.instagramHandle = "@test.user"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.instagramHandle, "test.user")
  }

  func testFrom_notesHTMLTagsStripped() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.notes = "<p>Great <strong>coach</strong> with <em>excellent</em> skills</p>"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.notes, "Great coach with excellent skills")
  }

  func testFrom_firstNameTrimmed() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "   John   "
    formState.lastName = "Smith"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.firstName, "John")
  }

  func testFrom_lastNameTrimmed() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "John"
    formState.lastName = "   Smith   "

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.lastName, "Smith")
  }

  func testFrom_emptyStringsConvertToNil() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.email = ""
    formState.phone = ""
    formState.twitterHandle = ""
    formState.instagramHandle = ""
    formState.notes = ""

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.email)
    XCTAssertNil(request.phone)
    XCTAssertNil(request.twitterHandle)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.notes)
  }

  // MARK: - Edge Case Tests

  func testFrom_atStrippingWhenNoAtPresent() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.twitterHandle = "testuser"  // No @
    formState.instagramHandle = "test.user"  // No @

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.twitterHandle, "testuser")
    XCTAssertEqual(request.instagramHandle, "test.user")
  }

  func testFrom_atStrippingOnlyStripsLeadingAt() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.twitterHandle = "@user@domain"  // @ in middle preserved
    formState.instagramHandle = "@test.@user"  // @ in middle preserved

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.twitterHandle, "user@domain")
    XCTAssertEqual(request.instagramHandle, "test.@user")
  }

  func testFrom_HTMLStrippingWithNestedTags() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.notes = "<div><p>Nested <span>tags</span> here</p></div>"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.notes, "Nested tags here")
  }

  func testFrom_HTMLStrippingWithSelfClosingTags() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.notes = "Line 1<br/>Line 2<hr/>Line 3"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.notes, "Line 1Line 2Line 3")
  }

  // MARK: - Integration Tests

  func testFrom_fullFormStateToRequestConversion() {
    // Given: A fully populated form
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = " Coach "
    formState.lastName = " Smith "
    formState.email = " COACH.SMITH@UNIVERSITY.EDU "
    formState.phone = "(555) 987-6543"
    formState.twitterHandle = "@coachsmith"
    formState.instagramHandle = "@coach.smith.official"
    formState.notes = "<p>Excellent recruiter</p><ul><li>Responsive</li></ul>"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "test-school-id",
      userId: "test-user-id",
      familyUnitId: "test-family-id"
    )

    // Then: Verify all transformations applied
    XCTAssertEqual(request.schoolId, "test-school-id")
    XCTAssertEqual(request.userId, "test-user-id")
    XCTAssertEqual(request.familyUnitId, "test-family-id")
    XCTAssertEqual(request.role, "head")
    XCTAssertEqual(request.firstName, "Coach")  // Trimmed
    XCTAssertEqual(request.lastName, "Smith")  // Trimmed
    XCTAssertEqual(request.email, "coach.smith@university.edu")  // Lowercased + trimmed
    XCTAssertEqual(request.phone, "(555) 987-6543")  // Preserved
    XCTAssertEqual(request.twitterHandle, "coachsmith")  // @ stripped
    XCTAssertEqual(request.instagramHandle, "coach.smith.official")  // @ stripped
    XCTAssertEqual(request.notes, "Excellent recruiterResponsive")  // HTML stripped
  }

  func testFrom_minimalFormStateToRequestConversion() {
    // Given: Form with only required fields
    var formState = CoachFormState()
    formState.role = .assistant
    formState.firstName = "Jane"
    formState.lastName = "Doe"

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "min-school",
      userId: "min-user",
      familyUnitId: "min-family"
    )

    // Then: Required fields set, optional fields nil
    XCTAssertEqual(request.schoolId, "min-school")
    XCTAssertEqual(request.userId, "min-user")
    XCTAssertEqual(request.familyUnitId, "min-family")
    XCTAssertEqual(request.role, "assistant")
    XCTAssertEqual(request.firstName, "Jane")
    XCTAssertEqual(request.lastName, "Doe")
    XCTAssertNil(request.email)
    XCTAssertNil(request.phone)
    XCTAssertNil(request.twitterHandle)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.notes)
  }

  func testFrom_whitespaceOnlyFieldsConvertToNil() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = "Test"
    formState.lastName = "User"
    formState.email = "   "  // Whitespace only
    formState.notes = "   "  // Whitespace only

    // When
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: "school",
      userId: "user",
      familyUnitId: "family"
    )

    // Then: Whitespace trimmed, empty string becomes nil
    XCTAssertNil(request.email)
    XCTAssertNil(request.notes)
  }
}
