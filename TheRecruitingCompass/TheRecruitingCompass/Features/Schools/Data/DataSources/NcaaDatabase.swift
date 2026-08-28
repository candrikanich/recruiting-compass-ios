//
//  NcaaDatabase.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  NCAA Division database for auto-filling division and conference
//

import Foundation
import OSLog

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "NcaaDatabase"
)

/// Protocol for NCAA database lookups (enables testing)
protocol NcaaDatabaseManaging: Sendable {
  func lookup(schoolName: String) async -> NcaaLookupResult?
}

/// NCAA Division database singleton
/// Loads D1, D2, D3 schools from bundled JSON resources
actor NcaaDatabase: NcaaDatabaseManaging {
  static let shared = NcaaDatabase()

  // MARK: - Properties

  private let d1Schools: [NcaaSchoolInfo]
  private let d2Schools: [NcaaSchoolInfo]
  private let d3Schools: [NcaaSchoolInfo]

  // Indexed lookup for O(1) exact matches
  private let schoolIndex: [String: (division: Division, school: NcaaSchoolInfo)]

  // Session cache for lookup results (actor provides isolation)
  private var lookupCache: [String: NcaaLookupResult] = [:]

  // MARK: - Init

  private init() {
    logger.debug("Initializing NCAA database")

    d1Schools = Self.loadSchools(from: "ncaa_d1")
    d2Schools = Self.loadSchools(from: "ncaa_d2")
    d3Schools = Self.loadSchools(from: "ncaa_d3")

    // Build index for O(1) exact lookups
    var index: [String: (division: Division, school: NcaaSchoolInfo)] = [:]

    for school in d1Schools {
      let normalized = Self.normalize(school.name)
      index[normalized] = (.d1, school)
    }
    for school in d2Schools {
      let normalized = Self.normalize(school.name)
      index[normalized] = (.d2, school)
    }
    for school in d3Schools {
      let normalized = Self.normalize(school.name)
      index[normalized] = (.d3, school)
    }

    schoolIndex = index

    // swiftlint:disable:next line_length
    logger.info("NCAA database loaded: D1=\(self.d1Schools.count), D2=\(self.d2Schools.count), D3=\(self.d3Schools.count), Indexed=\(self.schoolIndex.count)")
  }

  // MARK: - Public API

  /// Look up division and conference for a school name
  /// - Parameter schoolName: The school name to search for
  /// - Returns: NcaaLookupResult if found, nil otherwise
  func lookup(schoolName: String) async -> NcaaLookupResult? {
    guard !schoolName.isEmpty else { return nil }

    let normalized = normalizeSchoolName(schoolName)

    // Check cache first
    if let cached = getCachedResult(for: normalized) {
      logger.debug("NCAA cache hit for: \(schoolName)")
      return cached
    }

    logger.debug("NCAA lookup for: \(schoolName) (normalized: \(normalized))")

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

    logger.debug("No NCAA match found for: \(schoolName)")
    return nil
  }

  /// Clear the session cache
  func clearCache() {
    lookupCache.removeAll()
    logger.debug("NCAA cache cleared")
  }

  // MARK: - Private Helpers

  /// Load schools from bundled JSON resource.
  /// Searches bundle root first, then `Resources/` subdirectory to handle
  /// different Xcode bundling behaviors (PBXFileSystemSynchronizedRootGroup
  /// may place files at the root or inside a subdirectory).
  nonisolated private static func loadSchools(from filename: String) -> [NcaaSchoolInfo] {
    let url = Bundle.main.url(forResource: filename, withExtension: "json")
      ?? Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Resources")

    guard let url else {
      logger.error("NCAA database file not found anywhere in bundle: \(filename).json — division/conference auto-fill will not work")
      return []
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let schools = try decoder.decode([NcaaSchoolInfo].self, from: data)
      logger.debug("Loaded \(schools.count) schools from \(filename).json at \(url.path)")
      return schools
    } catch {
      logger.error("Failed to decode NCAA database \(filename).json: \(error.localizedDescription)")
      return []
    }
  }

  /// Search for a school name in a division's school list
  private func searchDivision(
    _ normalizedName: String,
    in schools: [NcaaSchoolInfo],
    division: Division
  ) -> NcaaLookupResult? {
    // Priority 1: Exact match (O(1) index lookup)
    if let (indexDivision, school) = schoolIndex[normalizedName], indexDivision == division {
      logger.debug("NCAA exact match (indexed): \(school.name) (\(division.rawValue))")
      return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
    }

    // Priority 2: Partial match (>8 chars)
    // Use Self.normalize (nonisolated static) inside closures to avoid actor isolation ambiguity
    if normalizedName.count > 8 {
      if let school = schools.first(where: {
        let schoolNormalized = Self.normalize($0.name)
        return schoolNormalized.contains(normalizedName) || normalizedName.contains(schoolNormalized)
      }) {
        logger.debug("NCAA partial match: \(school.name) (\(division.rawValue))")
        return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
      }
    }

    // Priority 3: Fuzzy match (Levenshtein distance <= 2)
    if let school = schools.first(where: {
      let schoolNormalized = Self.normalize($0.name)
      return normalizedName.levenshteinDistance(to: schoolNormalized) <= 2
    }) {
      logger.debug("NCAA fuzzy match: \(school.name) (\(division.rawValue))")
      return NcaaLookupResult(division: division, conference: school.conference ?? "", logo: school.logo)
    }

    return nil
  }

  /// Normalize school name for matching
  /// - Lowercase
  /// - Remove "University", "College", "The" prefixes
  /// - Remove punctuation
  /// - Trim whitespace
  private func normalizeSchoolName(_ name: String) -> String {
    Self.normalize(name)
  }

  /// Static normalization for use during initialization and externally
  nonisolated private static func normalize(_ name: String) -> String {
    let lowercased = name.lowercased()
    // Strip College Scorecard campus suffixes before removing punctuation to avoid
    // merging words: "University-Main Campus" → "UniversityMain Campus" (wrong)
    let withoutCampusSuffix = removeCampusSuffix(from: lowercased)
    let withoutLocationSuffix = removeAtLocationSuffix(from: withoutCampusSuffix)
    let withoutPrefixes = removePrefixes(from: withoutLocationSuffix)
    let withoutPunctuation = removePunctuation(from: withoutPrefixes)
    return normalizeWhitespace(in: withoutPunctuation)
  }

  /// Remove "- Main Campus", "-Main Campus", " Main Campus" suffixes appended by College Scorecard
  nonisolated private static func removeCampusSuffix(from text: String) -> String {
    guard let range = text.range(
      of: #"[-\s]+main\s+campus$"#,
      options: [.regularExpression, .caseInsensitive]
    ) else { return text }
    return String(text[..<range.lowerBound])
  }

  /// Remove " at [city]" suffixes appended by College Scorecard for branch campuses
  nonisolated private static func removeAtLocationSuffix(from text: String) -> String {
    guard let range = text.range(
      of: #"\s+at\s+.+$"#,
      options: .regularExpression
    ) else { return text }
    return String(text[..<range.lowerBound])
  }

  /// Remove common institutional prefixes
  nonisolated private static func removePrefixes(from text: String) -> String {
    let prefixes = ["university of ", "college of ", "the ", "university ", "college "]

    for prefix in prefixes where text.hasPrefix(prefix) {
      return String(text.dropFirst(prefix.count))
    }

    return text
  }

  /// Remove punctuation characters
  nonisolated private static func removePunctuation(from text: String) -> String {
    text.components(separatedBy: CharacterSet.punctuationCharacters).joined()
  }

  /// Normalize whitespace (collapse and trim)
  nonisolated private static func normalizeWhitespace(in text: String) -> String {
    text.components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Cache Helpers (actor-isolated)

  private func getCachedResult(for normalizedName: String) -> NcaaLookupResult? {
    lookupCache[normalizedName]
  }

  private func setCachedResult(_ result: NcaaLookupResult, for normalizedName: String) {
    lookupCache[normalizedName] = result
  }
}
