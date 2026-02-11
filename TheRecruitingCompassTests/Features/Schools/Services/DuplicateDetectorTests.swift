//
//  DuplicateDetectorTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11.
//

import XCTest
@testable import TheRecruitingCompass

final class DuplicateDetectorTests: XCTestCase {

  // MARK: - Test Data

  private func makeTestSchool(
    id: String = "test-id",
    name: String = "Stanford University",
    website: String? = "https://stanford.edu",
    ncaaId: String? = "123"
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
      website: website,
      ncaaId: ncaaId,
      familyUnitId: "family-id",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeTestRequest(
    name: String = "Test School",
    website: String? = nil,
    ncaaId: String? = nil
  ) -> SchoolCreateRequest {
    SchoolCreateRequest(
      userId: "user-id",
      familyUnitId: "family-id",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: nil,
      conference: nil,
      website: website,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: ncaaId,
      notes: nil,
      status: "active",
      academicInfo: nil
    )
  }

  // MARK: - Name Matching Tests

  func test_findDuplicate_exactNameMatch_caseInsensitive() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford University"),
      makeTestSchool(id: "2", name: "Harvard University")
    ]
    let request = makeTestRequest(name: "stanford university") // lowercase

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name)
  }

  func test_findDuplicate_nameMatch_withLeadingTrailingSpaces() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "  Stanford University  ") // spaces
    ]
    let request = makeTestRequest(name: "Stanford University")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name)
  }

  func test_findDuplicate_nameMatch_firstMatchReturned() {
    // Given - Multiple matches
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford University"),
      makeTestSchool(id: "2", name: "Stanford University") // duplicate name
    ]
    let request = makeTestRequest(name: "Stanford University")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1") // First match
    XCTAssertEqual(result.matchType, .name)
  }

  func test_findDuplicate_noDuplicate_differentName() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford University")
    ]
    let request = makeTestRequest(name: "Harvard University")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
    XCTAssertNil(result.matchType)
  }

  // MARK: - Domain Matching Tests

  func test_findDuplicate_domainMatch_withWWW() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://www.stanford.edu")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://stanford.edu") // no www

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func test_findDuplicate_domainMatch_withoutWWW() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://stanford.edu")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://www.stanford.edu") // with www

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func test_findDuplicate_domainMatch_caseSensitive() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://STANFORD.EDU")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://stanford.edu")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func test_findDuplicate_domainMatch_subdomain() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://admissions.stanford.edu")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://athletics.stanford.edu")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate) // Different subdomains should NOT match
  }

  func test_findDuplicate_noDuplicate_differentDomain() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://stanford.edu")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://harvard.edu")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
  }

  // MARK: - NCAA ID Matching Tests

  func test_findDuplicate_ncaaIdMatch() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "https://stanford.edu", ncaaId: "123")
    ]
    let request = makeTestRequest(name: "Different Name", website: "https://different.edu", ncaaId: "123")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .ncaaId)
  }

  func test_findDuplicate_noDuplicate_differentNcaaId() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", ncaaId: "123")
    ]
    let request = makeTestRequest(name: "Different Name", ncaaId: "456")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate)
  }

  // MARK: - Priority Order Tests

  func test_findDuplicate_prioritizesNameOverDomain() {
    // Given - School matches BOTH name and domain
    let existingSchools = [
      makeTestSchool(id: "name-match", name: "Stanford University", website: "https://stanford.edu"),
      makeTestSchool(id: "domain-match", name: "Different Name", website: "https://stanford.edu")
    ]
    let request = makeTestRequest(name: "Stanford University", website: "https://stanford.edu")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then - Should return name match (higher priority)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "name-match")
    XCTAssertEqual(result.matchType, .name)
  }

  func test_findDuplicate_prioritizesNameOverNcaaId() {
    // Given - School matches BOTH name and NCAA ID
    let existingSchools = [
      makeTestSchool(id: "name-match", name: "Stanford University", ncaaId: "123"),
      makeTestSchool(id: "ncaa-match", name: "Different Name", ncaaId: "123")
    ]
    let request = makeTestRequest(name: "Stanford University", ncaaId: "123")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then - Should return name match (higher priority)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "name-match")
    XCTAssertEqual(result.matchType, .name)
  }

  func test_findDuplicate_prioritizesDomainOverNcaaId() {
    // Given - School matches BOTH domain and NCAA ID
    let existingSchools = [
      makeTestSchool(id: "domain-match", name: "Domain Match", website: "https://stanford.edu", ncaaId: "999"),
      makeTestSchool(id: "ncaa-match", name: "NCAA Match", website: "https://different.edu", ncaaId: "123")
    ]
    let request = makeTestRequest(name: "New School", website: "https://stanford.edu", ncaaId: "123")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then - Should return domain match (higher priority)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "domain-match")
    XCTAssertEqual(result.matchType, .domain)
  }

  // MARK: - Edge Cases

  func test_findDuplicate_emptySchoolsList() {
    // Given
    let existingSchools: [School] = []
    let request = makeTestRequest(name: "Stanford University")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
  }

  func test_findDuplicate_noWebsite_noDomainMatch() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: nil)
    ]
    let request = makeTestRequest(name: "Different Name", website: nil)

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate) // Can't match on domain if no website
  }

  func test_findDuplicate_invalidURL_noDomainMatch() {
    // Given
    let existingSchools = [
      makeTestSchool(id: "1", name: "Stanford", website: "not-a-valid-url")
    ]
    let request = makeTestRequest(name: "Different Name", website: "also-not-valid")

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

    // Then
    XCTAssertFalse(result.isDuplicate)
  }

  // MARK: - Domain Extraction Tests

  func test_extractDomain_validURL() {
    // Given
    let url = "https://stanford.edu"

    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: url)

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func test_extractDomain_invalidURL_returnsNil() {
    // Given
    let url = "not-a-url"

    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: url)

    // Then
    XCTAssertNil(domain)
  }

  func test_extractDomain_stripsWWW() {
    // Given
    let url = "https://www.stanford.edu"

    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: url)

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func test_extractDomain_preservesSubdomain() {
    // Given
    let url = "https://admissions.stanford.edu"

    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: url)

    // Then
    XCTAssertEqual(domain, "admissions.stanford.edu")
  }

  func test_extractDomain_caseInsensitive() {
    // Given
    let url = "https://WWW.STANFORD.EDU"

    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: url)

    // Then
    XCTAssertEqual(domain, "STANFORD.EDU") // Preserves case, strips www
  }
}
