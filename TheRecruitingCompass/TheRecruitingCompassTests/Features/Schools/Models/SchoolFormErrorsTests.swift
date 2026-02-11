//
//  SchoolFormErrorsTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 1: Core Models - Unit tests for SchoolFormErrors
//

import XCTest
@testable import TheRecruitingCompass

final class SchoolFormErrorsTests: XCTestCase {

  // MARK: - hasErrors Tests

  func testHasErrors_whenAllNil_returnsFalse() {
    // Given
    let errors = SchoolFormErrors.empty

    // Then
    XCTAssertFalse(errors.hasErrors)
  }

  func testHasErrors_whenNameError_returnsTrue() {
    // Given
    let errors = SchoolFormErrors(name: "Name is required")

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  func testHasErrors_whenWebsiteError_returnsTrue() {
    // Given
    let errors = SchoolFormErrors(website: "Invalid URL")

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  func testHasErrors_whenMultipleErrors_returnsTrue() {
    // Given
    let errors = SchoolFormErrors(
      name: "Name is required",
      location: "Location is too long",
      website: "Invalid URL",
      notes: "Notes exceed character limit"
    )

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  // MARK: - allErrors Tests

  func testAllErrors_whenAllNil_returnsEmptyArray() {
    // Given
    let errors = SchoolFormErrors.empty

    // Then
    XCTAssertEqual(errors.allErrors, [])
  }

  func testAllErrors_whenOneError_returnsArrayWithOne() {
    // Given
    let errors = SchoolFormErrors(name: "Name is required")

    // Then
    XCTAssertEqual(errors.allErrors, ["Name is required"])
  }

  func testAllErrors_whenMultipleErrors_returnsAllErrors() {
    // Given
    let errors = SchoolFormErrors(
      name: "Name is required",
      website: "Invalid URL",
      notes: "Notes too long"
    )

    // Then
    XCTAssertEqual(errors.allErrors.count, 3)
    XCTAssertTrue(errors.allErrors.contains("Name is required"))
    XCTAssertTrue(errors.allErrors.contains("Invalid URL"))
    XCTAssertTrue(errors.allErrors.contains("Notes too long"))
  }

  func testAllErrors_whenAllErrors_returnsAllEleven() {
    // Given
    let errors = SchoolFormErrors(
      name: "Error 1",
      location: "Error 2",
      city: "Error 3",
      state: "Error 4",
      division: "Error 5",
      conference: "Error 6",
      website: "Error 7",
      twitterHandle: "Error 8",
      instagramHandle: "Error 9",
      notes: "Error 10",
      status: "Error 11"
    )

    // Then
    XCTAssertEqual(errors.allErrors.count, 11)
  }

  // MARK: - Static empty Tests

  func testEmpty_hasNoErrors() {
    // Given
    let errors = SchoolFormErrors.empty

    // Then
    XCTAssertNil(errors.name)
    XCTAssertNil(errors.location)
    XCTAssertNil(errors.city)
    XCTAssertNil(errors.state)
    XCTAssertNil(errors.division)
    XCTAssertNil(errors.conference)
    XCTAssertNil(errors.website)
    XCTAssertNil(errors.twitterHandle)
    XCTAssertNil(errors.instagramHandle)
    XCTAssertNil(errors.notes)
    XCTAssertNil(errors.status)
    XCTAssertFalse(errors.hasErrors)
    XCTAssertEqual(errors.allErrors, [])
  }
}
