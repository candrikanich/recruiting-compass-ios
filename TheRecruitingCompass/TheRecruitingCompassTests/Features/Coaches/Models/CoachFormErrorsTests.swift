//
//  CoachFormErrorsTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Unit tests for CoachFormErrors
//

import XCTest
@testable import TheRecruitingCompass

final class CoachFormErrorsTests: XCTestCase {

  // MARK: - hasErrors Tests

  func testHasErrors_whenAllNil_returnsFalse() {
    // Given
    let errors = CoachFormErrors.empty

    // Then
    XCTAssertFalse(errors.hasErrors)
  }

  func testHasErrors_whenRoleError_returnsTrue() {
    // Given
    let errors = CoachFormErrors(
      role: "Role is required",
      firstName: nil,
      lastName: nil,
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  func testHasErrors_whenFirstNameError_returnsTrue() {
    // Given
    let errors = CoachFormErrors(
      role: nil,
      firstName: "First name is required",
      lastName: nil,
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  func testHasErrors_whenMultipleErrors_returnsTrue() {
    // Given
    let errors = CoachFormErrors(
      role: "Role is required",
      firstName: "First name is required",
      lastName: "Last name is required",
      email: "Invalid email",
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // Then
    XCTAssertTrue(errors.hasErrors)
  }

  // MARK: - allErrors Tests

  func testAllErrors_whenAllNil_returnsEmptyArray() {
    // Given
    let errors = CoachFormErrors.empty

    // Then
    XCTAssertEqual(errors.allErrors, [])
  }

  func testAllErrors_whenOneError_returnsArrayWithOne() {
    // Given
    let errors = CoachFormErrors(
      role: "Role is required",
      firstName: nil,
      lastName: nil,
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // Then
    XCTAssertEqual(errors.allErrors, ["Role is required"])
  }

  func testAllErrors_whenMultipleErrors_returnsAllErrors() {
    // Given
    let errors = CoachFormErrors(
      role: "Role is required",
      firstName: "First name is required",
      lastName: "Last name is required",
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil
    )

    // Then
    XCTAssertEqual(errors.allErrors.count, 3)
    XCTAssertTrue(errors.allErrors.contains("Role is required"))
    XCTAssertTrue(errors.allErrors.contains("First name is required"))
    XCTAssertTrue(errors.allErrors.contains("Last name is required"))
  }

  func testAllErrors_whenAllErrors_returnsAllEight() {
    // Given
    let errors = CoachFormErrors(
      role: "Error 1",
      firstName: "Error 2",
      lastName: "Error 3",
      email: "Error 4",
      phone: "Error 5",
      twitterHandle: "Error 6",
      instagramHandle: "Error 7",
      notes: "Error 8"
    )

    // Then
    XCTAssertEqual(errors.allErrors.count, 8)
  }

  // MARK: - Static empty Tests

  func testEmpty_hasNoErrors() {
    // Given
    let errors = CoachFormErrors.empty

    // Then
    XCTAssertNil(errors.role)
    XCTAssertNil(errors.firstName)
    XCTAssertNil(errors.lastName)
    XCTAssertNil(errors.email)
    XCTAssertNil(errors.phone)
    XCTAssertNil(errors.twitterHandle)
    XCTAssertNil(errors.instagramHandle)
    XCTAssertNil(errors.notes)
    XCTAssertFalse(errors.hasErrors)
    XCTAssertEqual(errors.allErrors, [])
  }
}
