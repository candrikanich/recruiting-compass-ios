//
//  NcaaDatabase.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  NCAA Division database for auto-filling division and conference
//

import Foundation
import SwiftUI
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "NcaaDatabase"
)

/// Protocol for NCAA database lookups (enables testing)
protocol NcaaDatabaseManaging: Sendable {
  func lookup(schoolName: String) -> NcaaLookupResult?
}

/// NCAA Division database singleton
/// Loads D1, D2, D3 schools from bundled JSON resources
final class NcaaDatabase: NcaaDatabaseManaging, @unchecked Sendable {
  static let shared = NcaaDatabase()

  // MARK: - Properties

  private let d1Schools: [NcaaSchoolInfo]
  private let d2Schools: [NcaaSchoolInfo]
  private let d3Schools: [NcaaSchoolInfo]

  // Indexed lookup for O(1) exact matches
  private let schoolIndex: [String: (division: Division, school: NcaaSchoolInfo)]

  // Session cache for lookup results
  private var lookupCache: [String: NcaaLookupResult] = [:]
  private let cacheQueue = DispatchQueue(label: "com.recruitingcompass.ncaa.cache")

  // MARK: - Init

  private init() {
    logger.debug("Initializing NCAA database")

    d1Schools = Self.loadSchools(from: "ncaa_d1")
    d2Schools = Self.loadSchools(from: "ncaa_d2")
    d3Schools = Self.loadSchools(from: "ncaa_d3")

    // Build index for O(1) exact lookups
    var index: [String: (division: Division, school: NcaaSchoolInfo)] = [:]

    for school in d1Schools {
      let normalized = Self.normalizeSchoolNameStatic(school.name)
      index[normalized] = (.d1, school)
    }
    for school in d2Schools {
      let normalized = Self.normalizeSchoolNameStatic(school.name)
      index[normalized] = (.d2, school)
    }
    for school in d3Schools {
      let normalized = Self.normalizeSchoolNameStatic(school.name)
      index[normalized] = (.d3, school)
    }

    schoolIndex = index

    logger.info("NCAA database loaded: D1=\(self.d1Schools.count), D2=\(self.d2Schools.count), D3=\(self.d3Schools.count), Indexed=\(self.schoolIndex.count)")
  }

  // MARK: - Public API

  /// Look up division and conference for a school name
  /// - Parameter schoolName: The school name to search for
  /// - Returns: NcaaLookupResult if found, nil otherwise
  func lookup(schoolName: String) -> NcaaLookupResult? {
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
    cacheQueue.sync {
      lookupCache.removeAll()
    }
    logger.debug("NCAA cache cleared")
  }

  // MARK: - Private Helpers

  /// Load schools from bundled JSON resource
  private static func loadSchools(from filename: String) -> [NcaaSchoolInfo] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
      logger.warning("NCAA database file not found: \(filename).json")
      return []
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let schools = try decoder.decode([NcaaSchoolInfo].self, from: data)
      logger.debug("Loaded \(schools.count) schools from \(filename).json")
      return schools
    } catch {
      logger.error("Failed to load NCAA database \(filename).json: \(error.localizedDescription)")
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
      return NcaaLookupResult(division: division, conference: school.conference, logo: school.logo)
    }

    // Priority 2: Partial match (>8 chars)
    if normalizedName.count > 8 {
      if let school = schools.first(where: {
        let schoolNormalized = normalizeSchoolName($0.name)
        return schoolNormalized.contains(normalizedName) || normalizedName.contains(schoolNormalized)
      }) {
        logger.debug("NCAA partial match: \(school.name) (\(division.rawValue))")
        return NcaaLookupResult(division: division, conference: school.conference, logo: school.logo)
      }
    }

    // Priority 3: Fuzzy match (Levenshtein distance <= 2)
    if let school = schools.first(where: {
      levenshteinDistance(normalizedName, normalizeSchoolName($0.name)) <= 2
    }) {
      logger.debug("NCAA fuzzy match: \(school.name) (\(division.rawValue))")
      return NcaaLookupResult(division: division, conference: school.conference, logo: school.logo)
    }

    return nil
  }

  /// Normalize school name for matching
  /// - Lowercase
  /// - Remove "University", "College", "The" prefixes
  /// - Remove punctuation
  /// - Trim whitespace
  private func normalizeSchoolName(_ name: String) -> String {
    Self.normalizeSchoolNameStatic(name)
  }

  /// Static version of normalizeSchoolName for use during initialization
  private static func normalizeSchoolNameStatic(_ name: String) -> String {
    var normalized = name.lowercased()

    // Remove common prefixes
    let prefixes = ["university of ", "college of ", "the ", "university ", "college "]
    for prefix in prefixes {
      if normalized.hasPrefix(prefix) {
        normalized = String(normalized.dropFirst(prefix.count))
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

  /// Calculate Levenshtein distance between two strings
  /// Used for fuzzy matching (distance <= 2 is considered a match)
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

  // MARK: - Cache Helpers

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
