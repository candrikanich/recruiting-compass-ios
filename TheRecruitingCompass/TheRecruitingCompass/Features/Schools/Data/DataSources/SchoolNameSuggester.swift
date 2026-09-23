//
//  SchoolNameSuggester.swift
//  TheRecruitingCompass
//
//  Typo-tolerant school name suggestions (issue #140)
//

import Foundation

/// Suggests correctly spelled school names for a misspelled query.
/// Every significant query token must land within an edit-distance budget of some name token,
/// so "Michgan" finds "University of Michigan" while unrelated names never qualify.
enum SchoolNameSuggester {
  /// Words that appear in most school names and would make every school a fuzzy match.
  private static let genericTokens: Set<String> = ["university", "college", "of", "the", "at", "state"]

  nonisolated static func suggestions(for query: String, from names: [String], limit: Int = 3) -> [String] {
    let queryTokens = tokens(in: query).filter { !genericTokens.contains($0) }
    guard !queryTokens.isEmpty else { return [] }

    return names
      .compactMap { name -> (name: String, distance: Int)? in
        guard let distance = totalDistance(of: queryTokens, to: tokens(in: name)) else { return nil }
        return (name, distance)
      }
      .sorted { ($0.distance, $0.name.count) < ($1.distance, $1.name.count) }
      .prefix(limit)
      .map(\.name)
  }

  /// Sum of each query token's best distance, or nil if any token has no acceptable match.
  private nonisolated static func totalDistance(of queryTokens: [String], to nameTokens: [String]) -> Int? {
    var total = 0
    for queryToken in queryTokens {
      let budget = maxDistance(forTokenLength: queryToken.count)
      let best = nameTokens
        .map { queryToken.levenshteinDistance(to: $0) }
        .min()
      guard let best, best <= budget else { return nil }
      total += best
    }
    return total
  }

  /// Short tokens must match exactly; otherwise "mat" would match "mit".
  private nonisolated static func maxDistance(forTokenLength length: Int) -> Int {
    switch length {
    case ..<4: 0
    case 4...6: 1
    default: 2
    }
  }

  private nonisolated static func tokens(in text: String) -> [String] {
    text.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
  }
}
