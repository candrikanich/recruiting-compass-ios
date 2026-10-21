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

  func testFrom_withAllFields_createsRequestCorrectly() throws {
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
    let request = try SchoolCreateRequest.from(
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

  func testFrom_withRequiredFieldsOnly_createsRequestCorrectly() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "Stanford"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
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

  func testFrom_withMixedRequiredAndOptional_createsRequestCorrectly() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "MIT"
    formState.division = .d3
    formState.website = "https://mit.edu"
    formState.status = .contacted
    // Leave other fields empty

    // When
    let request = try SchoolCreateRequest.from(
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

  func testFrom_nameIsTrimmed() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "   Yale University   "
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.name, "Yale University")
  }

  func testFrom_emptyLocationConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.location = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.location)
  }

  func testFrom_whitespaceOnlyLocationConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.location = "   "
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.location)
  }

  func testFrom_emptyCityConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.city = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.city)
  }

  func testFrom_emptyStateConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.state = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.state)
  }

  func testFrom_divisionConvertsToRawValue() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.division = .naia
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.division, "NAIA")
  }

  func testFrom_nilDivisionStaysNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.division = nil
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.division)
  }

  func testFrom_emptyConferenceConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.conference = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.conference)
  }

  func testFrom_websiteIsTrimmedAndNilIfEmpty() throws {
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
    let request1 = try SchoolCreateRequest.from(
      form: formState1,
      userId: "user",
      familyUnitId: "family"
    )
    let request2 = try SchoolCreateRequest.from(
      form: formState2,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request1.website, "https://example.com")
    XCTAssertNil(request2.website)
  }

  func testFrom_twitterHandleStripsLeadingAt() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.twitterHandle = "@SchoolAthletics"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.twitterHandle, "SchoolAthletics")
  }

  func testFrom_instagramHandleStripsLeadingAt() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.instagramHandle = "@school.athletics"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.instagramHandle, "school.athletics")
  }

  func testFrom_emptyTwitterHandleConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.twitterHandle = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.twitterHandle)
  }

  func testFrom_emptyInstagramHandleConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.instagramHandle = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.instagramHandle)
  }

  func testFrom_notesStripsHtmlTags() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.notes = "<p>This is <strong>great</strong> school</p>"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.notes, "This is great school")
  }

  func testFrom_emptyNotesConvertsToNil() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.notes = ""
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.notes)
  }

  func testFrom_statusConvertsToRawValue() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .offerReceived

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertEqual(request.status, "offer_received")
  }

  // MARK: - MVP Constraints Tests

  func testFrom_ncaaIdIsAlwaysNilInMVP() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.ncaaId)
  }

  func testFrom_academicInfoIsAlwaysNilInMVP() throws {
    // Given
    var formState = SchoolFormState()
    formState.name = "School"
    formState.status = .interested

    // When
    let request = try SchoolCreateRequest.from(
      form: formState,
      scorecardData: nil,
      userId: "user",
      familyUnitId: "family"
    )

    // Then
    XCTAssertNil(request.academicInfo)
  }

  // MARK: - from(recommendation:)

  // Prod bug (build 111/115): adding a dashboard recommendation sent status "tracking", which is not a
  // school_status enum value, so every insert 400'd and the user saw "Couldn't add school".
  func test_fromRecommendation_usesAStatusTheDatabaseAccepts() throws {
    let request = try SchoolCreateRequest.from(
      recommendation: SchoolRecommendation(catalogKey: "k1", name: "State U", score: 0.9, reasons: []),
      userId: "user-1",
      familyUnitId: "fam-1"
    )
    XCTAssertNotNil(SchoolStatus(rawValue: request.status), "status must be a school_status enum value")
    XCTAssertEqual(request.status, SchoolStatus.researching.rawValue)
  }

  func test_fromRecommendation_carriesRecommendationFields() throws {
    let recommendation = SchoolRecommendation(
      catalogKey: "k1", name: "State U", division: "D1", conference: "Big Ten", state: "OH",
      website: "https://stateu.edu", score: 0.9, reasons: []
    )
    let request = try SchoolCreateRequest.from(recommendation: recommendation, userId: "user-1", familyUnitId: "fam-1")
    XCTAssertEqual(request.name, "State U")
    XCTAssertEqual(request.division, "D1")
    XCTAssertEqual(request.conference, "Big Ten")
    XCTAssertEqual(request.state, "OH")
    XCTAssertEqual(request.userId, "user-1")
    XCTAssertEqual(request.familyUnitId, "fam-1")
  }
}
