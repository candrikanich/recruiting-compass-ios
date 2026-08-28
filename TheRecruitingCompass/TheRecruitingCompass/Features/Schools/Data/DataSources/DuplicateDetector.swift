//
//  DuplicateDetector.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11.
//

import Foundation

/// Service for detecting duplicate schools based on multiple criteria
struct DuplicateDetector: Sendable {

  /// Check all duplicate criteria in priority order: name > domain > NCAA ID
  static func findDuplicate(
    in existingSchools: [School],
    for input: SchoolCreateRequest
  ) -> DuplicateResult {

    // Priority 1: Name match (case-insensitive exact)
    let inputName = input.name.trimmingCharacters(in: .whitespaces).lowercased()

    if let nameMatch = existingSchools.first(where: {
      $0.name.trimmingCharacters(in: .whitespaces).lowercased() == inputName
    }) {
      return DuplicateResult(duplicate: nameMatch, matchType: .name)
    }

    // Priority 2: Domain match (extract hostname, compare)
    if let website = input.website,
       let inputDomain = extractDomain(from: website) {
      if let domainMatch = existingSchools.first(where: {
        guard let existingWebsite = $0.website,
              let existingDomain = extractDomain(from: existingWebsite) else { return false }
        return existingDomain.lowercased() == inputDomain.lowercased()
      }) {
        return DuplicateResult(duplicate: domainMatch, matchType: .domain)
      }
    }

    // Priority 3: NCAA ID match (if available)
    if let ncaaId = input.ncaaId, !ncaaId.isEmpty {
      if let ncaaMatch = existingSchools.first(where: {
        $0.ncaaId == ncaaId
      }) {
        return DuplicateResult(duplicate: ncaaMatch, matchType: .ncaaId)
      }
    }

    return DuplicateResult(duplicate: nil, matchType: nil)
  }

  /// Extract domain from URL, stripping "www." prefix
  private static func extractDomain(from urlString: String) -> String? {
    // Handle URLs without scheme
    let normalizedURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"

    guard let url = URL(string: normalizedURL),
          let host = url.host else { return nil }

    // Strip "www." prefix (case-insensitive)
    return host.replacingOccurrences(
      of: "^www\\.",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
  }

  // MARK: - Testing Support

  /// Exposed for testing only - extracts domain from URL
  static func extractDomainForTesting(from urlString: String) -> String? {
    return extractDomain(from: urlString)
  }
}
