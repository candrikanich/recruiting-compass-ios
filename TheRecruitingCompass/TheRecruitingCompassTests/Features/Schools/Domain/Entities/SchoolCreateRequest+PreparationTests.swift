//
//  SchoolCreateRequest+PreparationTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 2: Validation System - SchoolCreateRequest preparation tests
//

import XCTest
@testable import TheRecruitingCompass

final class SchoolCreateRequestPreparationTests: XCTestCase {

  // MARK: - Initialization Tests

  func testFrom_withAllFields_createsRequestCorrectly() {
    // Given
    var formState = SchoolFormState()
    formState.name = " Harvard University "
    formState.location = " Cambridge, MA "
    formState.city = " Cambridge "
    formState.state = " Massachusetts "
    formState.division = .d1
    formState.conference = " Ivy League "
    formState.website = " https://harvard.edu "
    formState.twitterHandle = "@Harvard"
    formState.instagramHandle = "@harvard"
    formState.notes = "<p>Great academic school</p>"
    formState.status = .recruited

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      scorecardData: nil,
      userId: "user-123",
      familyUnitId: "family-456"
    )

    // Then
    XCTAssertEqual(request.userId, "user-123")
    XCTAssertEqual(request.familyUnitId, "family-456")
    XCTAssertEqual(request.name, "Harvard University")
    XCTAssertEqual(request.location, "Cambridge, MA")
    XCTAssertEqual(request.city, "Cambridge")
    XCTAssertEqual(request.state, "Massachusetts")
    XCTAssertEqual(request.division, "D1")
    XCTAssertEqual(request.conference, "Ivy League")
    XCTAssertEqual(request.website, "https://harvard.edu")
    XCTAssertEqual(request.twitterHandle, "Harvard")
    XCTAssertEqual(request.instagramHandle, "harvard")
    XCTAssertNil(request.ncaaId) // MVP: always nil
    XCTAssertEqual(request.notes, "Great academic school")
    XCTAssertEqual(request.status, "recruited")
    XCTAssertNil(request.academicInfo) // MVP: always nil
  }

  func testFrom_withRequiredFieldsOnly_createsRequestCorrectly() {
    // Given
    var formState = SchoolFormState()
    formState.name = "Stanford"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user-abc",
      familyUnitId: "family-xyz"
    )

    // Then
    XCTAssertEqual(request.userId, "user-abc")
    XCTAssertEqual(request.familyUnitId, "family-xyz")
    XCTAssertEqual(request.name, "Stanford")
    XCTAssertNil(request.location)
    XCTAssertNil(request.city)
    XCTAssertNil(request.state)
    XCTAssertNil(request.division)
    XCTAssertNil(request.conference)
    XCTAssertNil(request.website)
    XCTAssertNil(request.twitterHandle)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.ncaaId)
    XCTAssertNil(request.notes)
    XCTAssertEqual(request.status, "interested")
    XCTAssertNil(request.academicInfo)
  }

  func testFrom_withMixedRequiredAndOptional_createsRequestCorrectly() {
    // Given
    var formState = SchoolFormState()
    formState.name = "MIT"
    formState.division = .d3
    formState.website = "https://mit.edu"
    formState.status = .contacted
    // Leave other fields empty

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user-1",
      familyUnitId: "family-1"
    )

    // Then
    XCTAssertEqual(request.name, "MIT")
    XCTAssertEqual(request.division, "D3")
    XCTAssertEqual(request.website, "https://mit.edu")
    XCTAssertEqual(request.status, "contacted")
    XCTAssertNil(request.location)
    XCTAssertNil(request.city)
    XCTAssertNil(request.state)
    XCTAssertNil(request.conference)
    XCTAssertNil(request.twitterHandle)
    XCTAssertNil(request.instagramHandle)
    XCTAssertNil(request.notes)
  }

  // MARK: - Field Transformation Tests

  func testFrom_nameIsTrimmed() {
    // Given
    var formState = SchoolFormState()
    formState.name = "   Yale University   "
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.name, "Yale University")
  }

  func testFrom_emptyLocationConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.location = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.location)
  }

  func testFrom_whitespaceOnlyLocationConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.location = "   "
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.location)
  }

  func testFrom_emptyCityConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.city = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.city)
  }

  func testFrom_emptyStateConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.state = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.state)
  }

  func testFrom_divisionConvertsToRawValue() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.division = .naia
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.division, "NAIA")
  }

  func testFrom_nilDivisionStaysNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.division = nil
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.division)
  }

  func testFrom_emptyConferenceConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.conference = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.conference)
  }

  func testFrom_websiteIsTrimmedAndNilIfEmpty() {
    // Given
    var formState1 = SchoolFormState()
    formState1.name = "School"
    formState1.website = "  https://example.com  "
    formState1.status = .interested

    var formState2 = SchoolFormState()
    formState2.name = "School"
    formState2.website = ""
    formState2.status = .interested

    // When
    let request1 = SchoolCreateRequest.from(
      form: formState1,
      userId: "user",
      familyUnitId: "family"
    )
    let request2 = SchoolCreateRequest.from(
      form: formState2,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request1.website, "https://example.com")
    XCTAssertNil(request2.website)
  }

  func testFrom_twitterHandleStripsLeadingAt() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.twitterHandle = "@SchoolAthletics"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.twitterHandle, "SchoolAthletics")
  }

  func testFrom_instagramHandleStripsLeadingAt() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.instagramHandle = "@school.athletics"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.instagramHandle, "school.athletics")
  }

  func testFrom_emptyTwitterHandleConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.twitterHandle = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.twitterHandle)
  }

  func testFrom_emptyInstagramHandleConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.instagramHandle = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.instagramHandle)
  }

  func testFrom_notesStripsHtmlTags() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.notes = "<p>This is <strong>great</strong> school</p>"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.notes, "This is great school")
  }

  func testFrom_emptyNotesConvertsToNil() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.notes = ""
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.notes)
  }

  func testFrom_statusConvertsToRawValue() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .offerReceived

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.status, "offer_received")
  }

  // MARK: - MVP Constraints Tests

  func testFrom_ncaaIdIsAlwaysNilInMVP() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.ncaaId)
  }

  func testFrom_academicInfoIsAlwaysNilInMVP() {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .interested

    // When
    let request = SchoolCreateRequest.from(
      form: formState,
      scorecardData: nil,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.academicInfo)
  }
}
