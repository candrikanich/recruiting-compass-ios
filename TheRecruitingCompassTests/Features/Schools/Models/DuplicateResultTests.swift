//
//  DuplicateResultTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11.
//

import XCTest
@testable import TheRecruitingCompass

final class DuplicateResultTests: XCTestCase {

  // MARK: - Test Data

  private func makeTestSchool(
    id: String = "test-id",
    name: String = "Stanford University"
  ) -> School {
    School(
      id: id,
      userId: "user-id",
      name: name,
      location: "Stanford, CA",
      city: "Stanford",
      state: "CA",
      division: "D1",
      conference: "Pac-12",
      website: "https://stanford.edu",
      ncaaId: "123",
      familyUnitId: "family-id",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  // MARK: - DuplicateResult Tests

  func test_isDuplicate_true_whenDuplicateExists() {
    // Given
    let duplicate = makeTestSchool()
    let result = DuplicateResult(duplicate: duplicate, matchType: .name)

    // Then
    XCTAssertTrue(result.isDuplicate)
  }

  func test_isDuplicate_false_whenNoDuplicate() {
    // Given
    let result = DuplicateResult(duplicate: nil, matchType: nil)

    // Then
    XCTAssertFalse(result.isDuplicate)
  }

  func test_matchType_returnsCorrectType() {
    // Given
    let duplicate = makeTestSchool()
    let result = DuplicateResult(duplicate: duplicate, matchType: .domain)

    // Then
    XCTAssertEqual(result.matchType, .domain)
  }

  // MARK: - DuplicateMatchType Tests

  func test_displayLabel_name() {
    // Given
    let matchType = DuplicateMatchType.name

    // Then
    XCTAssertEqual(matchType.displayLabel, "Name Match")
  }

  func test_displayLabel_domain() {
    // Given
    let matchType = DuplicateMatchType.domain

    // Then
    XCTAssertEqual(matchType.displayLabel, "Website Domain")
  }

  func test_displayLabel_ncaaId() {
    // Given
    let matchType = DuplicateMatchType.ncaaId

    // Then
    XCTAssertEqual(matchType.displayLabel, "NCAA ID")
  }

  func test_badgeColor_name_isRed() {
    // Given
    let matchType = DuplicateMatchType.name

    // Then
    XCTAssertEqual(matchType.badgeColor, .red)
  }

  func test_badgeColor_domain_isYellow() {
    // Given
    let matchType = DuplicateMatchType.domain

    // Then
    XCTAssertEqual(matchType.badgeColor, .yellow)
  }

  func test_badgeColor_ncaaId_isOrange() {
    // Given
    let matchType = DuplicateMatchType.ncaaId

    // Then
    XCTAssertEqual(matchType.badgeColor, .orange)
  }

  func test_priority_nameHighest_ncaaIdLowest() {
    // Given
    let name = DuplicateMatchType.name
    let domain = DuplicateMatchType.domain
    let ncaaId = DuplicateMatchType.ncaaId

    // Then
    XCTAssertLessThan(name.priority, domain.priority)
    XCTAssertLessThan(domain.priority, ncaaId.priority)
    XCTAssertEqual(name.priority, 1)
    XCTAssertEqual(domain.priority, 2)
    XCTAssertEqual(ncaaId.priority, 3)
  }
}
