//
//  DuplicateDetectorTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Unit tests for duplicate school detection logic
//

import XCTest
@testable import TheRecruitingCompass

final class DuplicateDetectorTests: XCTestCase {

  var existingSchools: [School]!

  override func setUp() {
    super.setUp()

    // Create test schools
    existingSchools = [
      School.mock(
        id: "1",
        name: "University of Florida",
        website: "https://www.ufl.edu",
        ncaaId: "134130"
      ),
      School.mock(
        id: "2",
        name: "Stanford University",
        website: "https://www.stanford.edu",
        ncaaId: "243744"
      ),
      School.mock(
        id: "3",
        name: "MIT",
        website: "https://web.mit.edu",
        ncaaId: nil
      ),
      School.mock(
        id: "4",
        name: "Harvard University",
        website: nil, // No website
        ncaaId: "166027"
      )
    ]
  }

  override func tearDown() {
    existingSchools = nil
    super.tearDown()
  }

  // MARK: - Helper Methods

  private func makeRequest(
    name: String,
    website: String? = nil,
    ncaaId: String? = nil
  ) throws -> SchoolCreateRequest {
    try SchoolCreateRequest(
      userId: "user",
      familyUnitId: "family",
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
      status: "interested",
      academicInfo: nil,
      faviconUrl: nil
    )
  }

  // MARK: - Name Match Tests (Priority 1)

  func testFindDuplicate_exactNameMatch_returnsNameMatch() throws {
    // Given
    let input = try makeRequest(
      name: "University of Florida",
      website: "https://different-site.com"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name)
  }

  func testFindDuplicate_nameMatchCaseInsensitive_returnsNameMatch() throws {
    // Given
    let input = try makeRequest(
      name: "university of florida"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name)
  }

  func testFindDuplicate_nameMatchWithWhitespace_returnsNameMatch() throws {
    // Given
    let input = try makeRequest(
      name: "  University of Florida  "
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name)
  }

  func testFindDuplicate_nameMatchTakesPriorityOverDomain() throws {
    // Given - input matches BOTH name and domain
    let input = try makeRequest(
      name: "University of Florida",
      website: "https://www.ufl.edu"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should return name match (higher priority)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name) // Not .domain
  }

  func testFindDuplicate_nameMatchTakesPriorityOverNcaaId() throws {
    // Given - input matches BOTH name and NCAA ID
    let input = try makeRequest(
      name: "University of Florida",
      ncaaId: "134130"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should return name match (higher priority)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .name) // Not .ncaaId
  }

  // MARK: - Domain Match Tests (Priority 2)

  func testFindDuplicate_domainMatch_returnsDomainMatch() throws {
    // Given - different name, same domain
    let input = try makeRequest(
      name: "UF", // Different name
      website: "https://www.ufl.edu" // Same domain
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func testFindDuplicate_domainMatchIgnoresWWW_returnsDomainMatch() throws {
    // Given - domain with www vs without www
    let input = try makeRequest(
      name: "Different School",
      website: "https://stanford.edu" // No www
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should match stanford.edu (www stripped)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "2")
    XCTAssertEqual(result.matchType, .domain)
  }

  func testFindDuplicate_domainMatchCaseInsensitive_returnsDomainMatch() throws {
    // Given
    let input = try makeRequest(
      name: "Different School",
      website: "https://WWW.UFL.EDU"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func testFindDuplicate_domainMatchWithHTTP_returnsDomainMatch() throws {
    // Given - HTTP vs HTTPS shouldn't matter
    let input = try makeRequest(
      name: "Different School",
      website: "http://www.ufl.edu" // HTTP
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func testFindDuplicate_domainMatchWithPath_returnsDomainMatch() throws {
    // Given - URL path shouldn't affect domain matching
    let input = try makeRequest(
      name: "Different School",
      website: "https://www.ufl.edu/athletics/baseball"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain)
  }

  func testFindDuplicate_domainMatchWithSubdomain_noMatch() throws {
    // Given - subdomain should be considered part of the domain
    let input = try makeRequest(
      name: "Different School",
      website: "https://athletics.ufl.edu" // Different subdomain
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should NOT match (different subdomain)
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
  }

  func testFindDuplicate_domainMatchTakesPriorityOverNcaaId() throws {
    // Given - input matches BOTH domain and NCAA ID (but not name)
    let input = try makeRequest(
      name: "Different School",
      website: "https://www.ufl.edu",
      ncaaId: "134130"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should return domain match (higher priority than NCAA ID)
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .domain) // Not .ncaaId
  }

  // MARK: - NCAA ID Match Tests (Priority 3)

  func testFindDuplicate_ncaaIdMatch_returnsNcaaIdMatch() throws {
    // Given - different name and domain, same NCAA ID
    let input = try makeRequest(
      name: "Different School",
      website: "https://different-site.com",
      ncaaId: "134130" // Same NCAA ID as UF
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
    XCTAssertEqual(result.matchType, .ncaaId)
  }

  func testFindDuplicate_ncaaIdMatchCaseSensitive_noMatch() throws {
    // Given - NCAA IDs are case-sensitive (numeric typically)
    // This test assumes NCAA IDs are case-sensitive; if they're not, update detector logic
    let input = try makeRequest(
      name: "Different School",
      ncaaId: "134130" // Exact match needed
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.matchType, .ncaaId)
  }

  func testFindDuplicate_emptyNcaaId_noMatch() throws {
    // Given
    let input = try makeRequest(
      name: "Different School",
      ncaaId: "" // Empty string
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should not match on empty NCAA ID
    XCTAssertFalse(result.isDuplicate)
  }

  // MARK: - No Match Tests

  func testFindDuplicate_noMatch_returnsNil() throws {
    // Given - completely unique school
    let input = try makeRequest(
      name: "New Unique School",
      website: "https://unique-school.edu",
      ncaaId: "999999"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
    XCTAssertNil(result.matchType)
  }

  func testFindDuplicate_emptySchoolsList_returnsNil() throws {
    // Given
    let input = try makeRequest(
      name: "Any School"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: [], for: input)

    // Then
    XCTAssertFalse(result.isDuplicate)
    XCTAssertNil(result.duplicate)
  }

  func testFindDuplicate_noWebsiteInInput_skipsDomainCheck() throws {
    // Given - no website provided in input
    let input = try makeRequest(
      name: "Different School"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should not match on domain (input has no website)
    XCTAssertFalse(result.isDuplicate)
  }

  func testFindDuplicate_noWebsiteInExisting_skipsDomainCheck() throws {
    // Given - Harvard has no website
    let input = try makeRequest(
      name: "Different School",
      website: "https://harvard.edu"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then - should not match Harvard (it has no website)
    XCTAssertFalse(result.isDuplicate)
  }

  func testFindDuplicate_noNcaaIdInInput_skipsNcaaIdCheck() throws {
    // Given
    let input = try makeRequest(
      name: "Different School"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: existingSchools, for: input)

    // Then
    XCTAssertFalse(result.isDuplicate)
  }

  // MARK: - extractDomain() Helper Tests

  func testExtractDomain_httpsWithWWW_stripsWWW() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "https://www.stanford.edu")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_httpsWithoutWWW_returnsHost() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "https://stanford.edu")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_httpWithWWW_stripsWWW() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "http://www.stanford.edu")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_noScheme_addsSchemeThenExtracts() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "www.stanford.edu")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_withPath_returnsOnlyDomain() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "https://www.stanford.edu/athletics/baseball")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_withQueryString_returnsOnlyDomain() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "https://www.stanford.edu?page=home")

    // Then
    XCTAssertEqual(domain, "stanford.edu")
  }

  func testExtractDomain_withSubdomain_includesSubdomain() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "https://athletics.stanford.edu")

    // Then - subdomain is part of the domain
    XCTAssertEqual(domain, "athletics.stanford.edu")
  }

  func testExtractDomain_invalidURL_returnsNil() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "not a valid url")

    // Then
    XCTAssertNil(domain)
  }

  func testExtractDomain_emptyString_returnsNil() throws {
    // When
    let domain = DuplicateDetector.extractDomainForTesting(from: "")

    // Then
    XCTAssertNil(domain)
  }

  func testExtractDomain_wwwCaseInsensitive_stripsCorrectly() throws {
    // When
    let domain1 = DuplicateDetector.extractDomainForTesting(from: "https://WWW.stanford.edu")
    let domain2 = DuplicateDetector.extractDomainForTesting(from: "https://Www.stanford.edu")

    // Then
    XCTAssertEqual(domain1, "stanford.edu")
    XCTAssertEqual(domain2, "stanford.edu")
  }

  // MARK: - Edge Cases

  func testFindDuplicate_multipleMatches_returnsFirst() throws {
    // Given - two schools with same domain
    let schools = [
      School.mock(id: "1", name: "School A", website: "https://same.edu", ncaaId: nil),
      School.mock(id: "2", name: "School B", website: "https://same.edu", ncaaId: nil)
    ]

    let input = try makeRequest(
      name: "Different School",
      website: "https://same.edu"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: schools, for: input)

    // Then - should return first match
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.duplicate?.id, "1")
  }

  func testFindDuplicate_specialCharactersInName_matchesExactly() throws {
    // Given
    let schools = [
      School.mock(id: "1", name: "St. Mary's College", website: nil, ncaaId: nil)
    ]

    let input = try makeRequest(
      name: "St. Mary's College"
    )

    // When
    let result = DuplicateDetector.findDuplicate(in: schools, for: input)

    // Then
    XCTAssertTrue(result.isDuplicate)
    XCTAssertEqual(result.matchType, .name)
  }
}

// MARK: - School.mock Extension

extension School {
  static func mock(
    id: String,
    name: String,
    website: String? = nil,
    ncaaId: String? = nil
  ) -> School {
    School(
      id: id,
      userId: "user",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: nil,
      conference: nil,
      ranking: nil,
      isFavorite: false,
      website: website,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: ncaaId,
      status: "interested",
      statusChangedAt: nil,
      notes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      familyUnitId: "family",
      createdBy: "user",
      updatedBy: "user",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }
}
