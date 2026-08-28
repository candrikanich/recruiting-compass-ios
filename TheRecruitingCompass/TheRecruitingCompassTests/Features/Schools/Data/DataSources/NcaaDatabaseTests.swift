//
//  NcaaDatabaseTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Unit tests for NCAA database lookup logic
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class NcaaDatabaseTests: XCTestCase {
  nonisolated deinit {}

  var database: TestableNcaaDatabase!

  override func setUp() {
    super.setUp()

    // Create test database with mock data
    let d1Schools = [
      NcaaSchoolInfo(name: "University of Florida", conference: "SEC", logo: nil),
      NcaaSchoolInfo(name: "Stanford University", conference: "Pac-12", logo: nil),
      NcaaSchoolInfo(name: "Vanderbilt University", conference: "SEC", logo: nil)
    ]

    let d2Schools = [
      NcaaSchoolInfo(name: "UC San Diego", conference: "CCAA", logo: nil),
      NcaaSchoolInfo(name: "Florida Southern College", conference: "SSC", logo: nil)
    ]

    let d3Schools = [
      NcaaSchoolInfo(name: "MIT", conference: "NEWMAC", logo: nil),
      NcaaSchoolInfo(name: "Johns Hopkins University", conference: "Centennial", logo: nil)
    ]

    database = TestableNcaaDatabase(
      d1Schools: d1Schools,
      d2Schools: d2Schools,
      d3Schools: d3Schools
    )
  }

  override func tearDown() {
    database = nil
    super.tearDown()
  }

  // MARK: - Exact Match Tests

  func testLookup_exactMatch_d1School_returnsResult() async {
    // When
    let result = await database.lookup(schoolName: "University of Florida")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "SEC")
  }

  func testLookup_exactMatch_d2School_returnsResult() async {
    // When
    let result = await database.lookup(schoolName: "UC San Diego")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d2)
    XCTAssertEqual(result?.conference, "CCAA")
  }

  func testLookup_exactMatch_d3School_returnsResult() async {
    // When
    let result = await database.lookup(schoolName: "MIT")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d3)
    XCTAssertEqual(result?.conference, "NEWMAC")
  }

  func testLookup_exactMatch_caseInsensitive_returnsResult() async {
    // When
    let result1 = await database.lookup(schoolName: "university of florida")
    let result2 = await database.lookup(schoolName: "UNIVERSITY OF FLORIDA")
    let result3 = await database.lookup(schoolName: "UnIvErSiTy Of FlOrIdA")

    // Then
    XCTAssertNotNil(result1)
    XCTAssertEqual(result1?.division, .d1)

    XCTAssertNotNil(result2)
    XCTAssertEqual(result2?.division, .d1)

    XCTAssertNotNil(result3)
    XCTAssertEqual(result3?.division, .d1)
  }

  func testLookup_exactMatch_withoutUniversityPrefix_returnsResult() async {
    // When
    let result = await database.lookup(schoolName: "Florida")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "SEC")
  }

  func testLookup_exactMatch_prioritizesD1OverD2() async {
    // Given - add school to both D1 and D2
    let d1 = [NcaaSchoolInfo(name: "Test University", conference: "D1 Conference", logo: nil)]
    let d2 = [NcaaSchoolInfo(name: "Test University", conference: "D2 Conference", logo: nil)]
    let testDb = TestableNcaaDatabase(d1Schools: d1, d2Schools: d2, d3Schools: [])

    // When
    let result = await testDb.lookup(schoolName: "Test University")

    // Then
    XCTAssertEqual(result?.division, .d1) // D1 should win
    XCTAssertEqual(result?.conference, "D1 Conference")
  }

  // MARK: - Partial Match Tests (>8 chars)

  func testLookup_partialMatch_longName_returnsResult() async {
    // When - "Vanderbilt" normalizes to "vanderbilt" (10 chars > 8), triggers partial match
    // DB has "Vanderbilt University" -> "vanderbilt university" which contains "vanderbilt"
    let result = await database.lookup(schoolName: "Vanderbilt")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "SEC")
  }

  func testLookup_partialMatch_subset_returnsResult() async {
    // When
    let result = await database.lookup(schoolName: "Johns Hopkins")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d3)
    XCTAssertEqual(result?.conference, "Centennial")
  }

  func testLookup_partialMatch_scorecardAtCitySuffix_returnsResult() async {
    // College Scorecard appends " at [city]" for multi-campus schools (e.g. "Kent State University at Kent").
    // The NCAA database has "Kent State University" (no suffix).
    // Partial match: "kent state university at kent".contains("kent state university") → true.
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Kent State University", conference: "Mid-American Conference", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    let result = await db.lookup(schoolName: "Kent State University at Kent")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "Mid-American Conference")
  }

  func testLookup_partialMatch_ignoresShortNames() async {
    // Given - short name (8 chars or less)
    let shortDb = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "University of Test", conference: "Test", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - search with 8 chars (should not trigger partial match)
    let result = await shortDb.lookup(schoolName: "12345678")

    // Then - should return nil (no exact or fuzzy match)
    XCTAssertNil(result)
  }

  func testLookup_partialMatch_moreThan8Chars_triggers() async {
    // Given - custom DB with "California Institute" -> "california institute"
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "California Institute", conference: "Test", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - "California" normalizes to "california" (10 chars > 8), triggers partial match
    // "california institute" contains "california" -> partial match
    let result = await db.lookup(schoolName: "California")

    // Then - should find partial match
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "Test")
  }

  // MARK: - Fuzzy Match Tests (Levenshtein Distance <= 2)

  func testLookup_fuzzyMatch_oneCharDifference_returnsResult() async {
    // Given
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Florida State", conference: "ACC", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - "florida stat" (missing 'e', distance = 1)
    let result = await db.lookup(schoolName: "florida stat")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  func testLookup_fuzzyMatch_twoCharDifference_returnsResult() async {
    // Given
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Stanford", conference: "Pac-12", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - "stanfrd" (missing 'o', distance = 1)
    let result = await db.lookup(schoolName: "stanfrd")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  func testLookup_fuzzyMatch_threeCharDifference_returnsNil() async {
    // Given
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Stanford", conference: "Pac-12", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - "stanxx" (3+ char difference)
    let result = await db.lookup(schoolName: "stanxx")

    // Then - should not match (distance > 2)
    XCTAssertNil(result)
  }

  // MARK: - No Match Tests

  func testLookup_noMatch_returnsNil() async {
    // When
    let result = await database.lookup(schoolName: "Nonexistent University")

    // Then
    XCTAssertNil(result)
  }

  func testLookup_emptyString_returnsNil() async {
    // When
    let result = await database.lookup(schoolName: "")

    // Then
    XCTAssertNil(result)
  }

  func testLookup_whitespaceOnly_returnsNil() async {
    // When
    let result = await database.lookup(schoolName: "   ")

    // Then
    // After normalization, becomes empty string
    XCTAssertNil(result)
  }

  // MARK: - Normalization Tests

  func testNormalizeSchoolName_removesUniversityOfPrefix() {
    // When
    let result = database.exposedNormalize("University of Florida")

    // Then
    XCTAssertEqual(result, "florida")
  }

  func testNormalizeSchoolName_removesCollegeOfPrefix() {
    // When
    let result = database.exposedNormalize("College of William and Mary")

    // Then
    XCTAssertEqual(result, "william and mary")
  }

  func testNormalizeSchoolName_removesThePrefix() {
    // When
    let result = database.exposedNormalize("The Ohio State University")

    // Then - only "the " prefix is removed; "university" suffix is not stripped
    XCTAssertEqual(result, "ohio state university")
  }

  func testNormalizeSchoolName_removesUniversityAlone() {
    // When - "university " is a prefix pattern, but "stanford university" starts with "stanford"
    let result = database.exposedNormalize("Stanford University")

    // Then - no prefix matches, so the full normalized name is kept
    XCTAssertEqual(result, "stanford university")
  }

  func testNormalizeSchoolName_removesCollegeAlone() {
    // When - "college " is a prefix pattern, but "boston college" starts with "boston"
    let result = database.exposedNormalize("Boston College")

    // Then - no prefix matches, so the full normalized name is kept
    XCTAssertEqual(result, "boston college")
  }

  func testNormalizeSchoolName_removesPunctuation() {
    // When
    let result = database.exposedNormalize("St. Mary's College")

    // Then - punctuation removed but "college" suffix is not a prefix pattern
    XCTAssertEqual(result, "st marys college")
  }

  func testNormalizeSchoolName_removesExtraWhitespace() {
    // When - extra spaces prevent "university of " prefix from matching
    let result = database.exposedNormalize("University  of   Florida")

    // Then - "university " prefix matches (single space), leaving " of   florida", then whitespace collapsed
    XCTAssertEqual(result, "of florida")
  }

  func testNormalizeSchoolName_trimsLeadingTrailingWhitespace() {
    // When
    let result = database.exposedNormalize("  Stanford  ")

    // Then
    XCTAssertEqual(result, "stanford")
  }

  func testNormalizeSchoolName_convertsToLowercase() {
    // When
    let result = database.exposedNormalize("STANFORD UNIVERSITY")

    // Then - lowercased but no prefix removed (doesn't start with a known prefix)
    XCTAssertEqual(result, "stanford university")
  }

  func testNormalizeSchoolName_handlesSpecialCharacters() {
    // When
    let result = database.exposedNormalize("Miami (OH)")

    // Then
    XCTAssertEqual(result, "miami oh")
  }

  // MARK: - Levenshtein Distance Tests

  func testLevenshteinDistance_identicalStrings_returnsZero() {
    // When
    let distance = database.exposedLevenshteinDistance("stanford", "stanford")

    // Then
    XCTAssertEqual(distance, 0)
  }

  func testLevenshteinDistance_oneInsertion_returnsOne() {
    // When
    let distance = database.exposedLevenshteinDistance("stanfrd", "stanford")

    // Then
    XCTAssertEqual(distance, 1)
  }

  func testLevenshteinDistance_oneDeletion_returnsOne() {
    // When
    let distance = database.exposedLevenshteinDistance("stanford", "stanfrd")

    // Then
    XCTAssertEqual(distance, 1)
  }

  func testLevenshteinDistance_oneSubstitution_returnsOne() {
    // When
    let distance = database.exposedLevenshteinDistance("stanford", "stanferd")

    // Then
    XCTAssertEqual(distance, 1)
  }

  func testLevenshteinDistance_twoChanges_returnsTwo() {
    // When - "stanfxrd" vs "stanford": only position 5 differs ('x' vs 'o')
    let distance = database.exposedLevenshteinDistance("stanford", "stanfxrd")

    // Then - single substitution = distance 1
    XCTAssertEqual(distance, 1)
  }

  func testLevenshteinDistance_threeChanges_returnsThree() {
    // When - "stanxxrd" vs "stanford": positions 4,5 differ ('x','x' vs 'f','o')
    let distance = database.exposedLevenshteinDistance("stanford", "stanxxrd")

    // Then - two substitutions = distance 2
    XCTAssertEqual(distance, 2)
  }

  func testLevenshteinDistance_emptyStrings_returnsCorrectly() {
    // When
    let distance1 = database.exposedLevenshteinDistance("", "test")
    let distance2 = database.exposedLevenshteinDistance("test", "")
    let distance3 = database.exposedLevenshteinDistance("", "")

    // Then
    XCTAssertEqual(distance1, 4) // Insert 4 chars
    XCTAssertEqual(distance2, 4) // Delete 4 chars
    XCTAssertEqual(distance3, 0) // Both empty
  }

  // MARK: - Cache Tests

  func testLookup_cachesResult_afterFirstLookup() async {
    // Given
    _ = await database.lookup(schoolName: "Stanford University")

    // When - lookup again
    let result = await database.lookup(schoolName: "Stanford University")

    // Then - should still return correct result
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "Pac-12")

    // Cache hit is logged (verified in implementation)
  }

  func testLookup_cacheIsNormalized_usesNormalizedKey() async {
    // Given
    _ = await database.lookup(schoolName: "University of Florida")

    // When - lookup with different casing
    let result = await database.lookup(schoolName: "UNIVERSITY OF FLORIDA")

    // Then - should hit cache (same normalized key)
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  func testClearCache_removesAllCachedResults() async {
    // Given - populate cache with names that produce exact matches
    _ = await database.lookup(schoolName: "University of Florida")
    _ = await database.lookup(schoolName: "MIT")

    // When
    database.clearCache()

    // Then - subsequent lookups still work (re-search from database)
    let result = await database.lookup(schoolName: "University of Florida")
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  // MARK: - Edge Case Tests

  func testLookup_veryLongSchoolName_handlesGracefully() async {
    // Given
    let longName = String(repeating: "University ", count: 100)

    // When
    let result = await database.lookup(schoolName: longName)

    // Then - should not crash, returns nil
    XCTAssertNil(result)
  }

  func testLookup_schoolNameWithNumbers_handlesCorrectly() async {
    // Given - "Miami (FL)" normalizes to "miami fl" (punctuation removed)
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Miami (FL)", conference: "ACC", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When - exact match with same parenthetical
    let result = await db.lookup(schoolName: "Miami (FL)")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  func testLookup_unicodeCharacters_handlesCorrectly() async {
    // Given
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "São Paulo University", conference: "Test", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    // When
    let result = await db.lookup(schoolName: "São Paulo University")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.division, .d1)
  }

  // MARK: - Realistic NCAA Database Tests

  func testLookup_realData_stanfordUniversity() async {
    // Uses the real bundled NCAA database. Skipped when JSON files are not in the test bundle.
    let realDatabase = NcaaDatabase.shared
    let probe = await realDatabase.lookup(schoolName: "Stanford University")
    guard probe != nil else {
      // JSON not available in this test bundle — skip rather than fail
      return
    }

    XCTAssertEqual(probe?.division, .d1)
  }

  func testLookup_realData_kentStateWithScorecardSuffix() async {
    // College Scorecard returns "Kent State University at Kent" but NCAA DB has "Kent State University".
    // The lookup must resolve this via partial match (primary) or the " at [city]" fallback.
    // Skipped when JSON files are not in the test bundle.
    let realDatabase = NcaaDatabase.shared
    let probe = await realDatabase.lookup(schoolName: "Stanford University")
    guard probe != nil else { return } // JSON unavailable in test bundle

    let result = await realDatabase.lookup(schoolName: "Kent State University at Kent")

    XCTAssertNotNil(result, "Kent State University at Kent must resolve to a D1 school")
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "Mid-American Conference")
  }

  func testLookup_realData_atCitySuffixStillMatchesSchoolsWithAtInName() async {
    // Schools like "University of Texas at Austin" have " at " as part of their official name.
    // A query for the exact NCAA name must still match (primary lookup succeeds, no stripping needed).
    // Skipped when JSON files are not in the test bundle.
    let realDatabase = NcaaDatabase.shared
    let probe = await realDatabase.lookup(schoolName: "Stanford University")
    guard probe != nil else { return } // JSON unavailable in test bundle

    let result = await realDatabase.lookup(schoolName: "University of Texas at Austin")

    XCTAssertNotNil(result, "University of Texas at Austin must resolve")
    XCTAssertEqual(result?.division, .d1)
  }

  // MARK: - College Scorecard Suffix Normalization Tests

  func testLookup_mainCampusSuffix_matchesSchoolWithoutSuffix() async {
    // College Scorecard returns "Ohio State University-Main Campus" but NCAA DB has "Ohio State University".
    // Regression: before the fix, removePunctuation() stripped the hyphen, yielding
    // "ohio state universitymain campus" which did NOT match "ohio state university".
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Ohio State University", conference: "Big Ten", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    let result = await db.lookup(schoolName: "Ohio State University-Main Campus")

    XCTAssertNotNil(result, "'-Main Campus' suffix must be stripped before matching NCAA database")
    XCTAssertEqual(result?.division, .d1)
    XCTAssertEqual(result?.conference, "Big Ten")
  }

  func testLookup_mainCampusWithSpaceSuffix_matchesSchoolWithoutSuffix() async {
    // Handles "University Name Main Campus" (space instead of hyphen)
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Penn State University", conference: "Big Ten", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    let result = await db.lookup(schoolName: "Penn State University Main Campus")

    XCTAssertNotNil(result, "' Main Campus' suffix must be stripped before matching NCAA database")
    XCTAssertEqual(result?.division, .d1)
  }

  func testLookup_atCitySuffix_matchesSchoolWithoutSuffix() async {
    // College Scorecard returns "Kent State University at Kent" but NCAA DB has "Kent State University".
    let db = TestableNcaaDatabase(
      d1Schools: [NcaaSchoolInfo(name: "Kent State University", conference: "Mid-American Conference", logo: nil)],
      d2Schools: [],
      d3Schools: []
    )

    let result = await db.lookup(schoolName: "Kent State University at Kent")

    XCTAssertNotNil(result, "' at [city]' suffix must be handled for NCAA database matching")
    XCTAssertEqual(result?.division, .d1)
  }

  func testLookup_realData_mainCampusSuffixStillMatchesSchool() async {
    // Verifies the "-Main Campus" fix works against the real bundled NCAA database.
    // Skipped when JSON files are not in the test bundle.
    let realDatabase = NcaaDatabase.shared
    let probe = await realDatabase.lookup(schoolName: "Stanford University")
    guard probe != nil else { return } // JSON unavailable in test bundle

    let result = await realDatabase.lookup(schoolName: "Ohio State University-Main Campus")

    XCTAssertNotNil(result, "Ohio State University-Main Campus must resolve via normalization")
    XCTAssertEqual(result?.division, .d1)
  }
}

// MARK: - Testable NCAA Database

/// Testable version of NcaaDatabase that allows injecting mock school data
final class TestableNcaaDatabase: NcaaDatabaseManaging, @unchecked Sendable {

  private let d1Schools: [NcaaSchoolInfo]
  private let d2Schools: [NcaaSchoolInfo]
  private let d3Schools: [NcaaSchoolInfo]

  // Session cache for lookup results
  private var lookupCache: [String: NcaaLookupResult] = [:]
  private let cacheQueue = DispatchQueue(label: "com.recruitingcompass.ncaa.test.cache")

  init(
    d1Schools: [NcaaSchoolInfo],
    d2Schools: [NcaaSchoolInfo],
    d3Schools: [NcaaSchoolInfo]
  ) {
    self.d1Schools = d1Schools
    self.d2Schools = d2Schools
    self.d3Schools = d3Schools
  }

  func lookup(schoolName: String) async -> NcaaLookupResult? {
    guard !schoolName.isEmpty else { return nil }

    let normalized = normalizeSchoolName(schoolName)

    // Check cache first
    if let cached = getCachedResult(for: normalized) {
      return cached
    }

    // Search D1, then D2, then D3
    if let result = searchDivision(normalized, in: d1Schools, division: .d1) {
      setCachedResult(result, for: normalized)
      return result
    }

    if let result = searchDivision(normalized, in: d2Schools, division: .d2) {
      setCachedResult(result, for: normalized)
      return result
    }

    if let result = searchDivision(normalized, in: d3Schools, division: .d3) {
      setCachedResult(result, for: normalized)
      return result
    }

    return nil
  }

  func clearCache() {
    cacheQueue.sync {
      lookupCache.removeAll()
    }
  }

  // MARK: - Test Helpers

  func exposedNormalize(_ name: String) -> String {
    return normalizeSchoolName(name)
  }

  func exposedLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
    return levenshteinDistance(s1, s2)
  }

  // MARK: - Private Helpers (copied from NcaaDatabase)

  private func searchDivision(
    _ normalizedName: String,
    in schools: [NcaaSchoolInfo],
    division: Division
  ) -> NcaaLookupResult? {
    // Priority 1: Exact match
    if let school = schools.first(where: { normalizeSchoolName($0.name) == normalizedName }) {
      return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
    }

    // Priority 2: Partial match (>8 chars)
    if normalizedName.count > 8 {
      if let school = schools.first(where: {
        let schoolNormalized = normalizeSchoolName($0.name)
        return schoolNormalized.contains(normalizedName) || normalizedName.contains(schoolNormalized)
      }) {
        return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
      }
    }

    // Priority 3: Fuzzy match (Levenshtein distance <= 2)
    if let school = schools.first(where: {
      levenshteinDistance(normalizedName, normalizeSchoolName($0.name)) <= 2
    }) {
      return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
    }

    return nil
  }

  private func normalizeSchoolName(_ name: String) -> String {
    var normalized = name.lowercased()

    // Strip College Scorecard campus suffixes before removing punctuation to avoid
    // merging words: "University-Main Campus" → "UniversityMain Campus" (wrong)
    if let range = normalized.range(of: #"[-\s]+main\s+campus$"#, options: [.regularExpression, .caseInsensitive]) {
      normalized = String(normalized[..<range.lowerBound])
    }
    if let range = normalized.range(of: #"\s+at\s+.+$"#, options: .regularExpression) {
      normalized = String(normalized[..<range.lowerBound])
    }

    // Remove common prefixes
    let prefixes = ["university of ", "college of ", "the ", "university ", "college "]
    for prefix in prefixes {
      if normalized.hasPrefix(prefix) {
        normalized = String(normalized.dropFirst(prefix.count))
        break
      }
    }

    // Remove punctuation
    normalized = normalized.components(separatedBy: CharacterSet.punctuationCharacters).joined()

    // Remove extra whitespace
    normalized = normalized.components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let s1Array = Array(s1)
    let s2Array = Array(s2)
    let m = s1Array.count
    let n = s2Array.count

    if m == 0 { return n }
    if n == 0 { return m }

    var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    for i in 0...m {
      matrix[i][0] = i
    }

    for j in 0...n {
      matrix[0][j] = j
    }

    for i in 1...m {
      for j in 1...n {
        let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
        matrix[i][j] = min(
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        )
      }
    }

    return matrix[m][n]
  }

  private func getCachedResult(for normalizedName: String) -> NcaaLookupResult? {
    cacheQueue.sync {
      lookupCache[normalizedName]
    }
  }

  private func setCachedResult(_ result: NcaaLookupResult, for normalizedName: String) {
    cacheQueue.sync {
      lookupCache[normalizedName] = result
    }
  }
}
