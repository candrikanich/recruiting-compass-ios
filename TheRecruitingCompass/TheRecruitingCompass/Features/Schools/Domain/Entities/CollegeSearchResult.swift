//
//  CollegeSearchResult.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 2: College Scorecard Autocomplete
//

import Foundation

/// College search result from autocomplete dropdown
struct CollegeSearchResult: Identifiable, Codable, Sendable, Hashable {
  let id: String
  let name: String
  let city: String
  let state: String
  let website: String?

  /// Computed location string for display
  var location: String {
    "\(city), \(state)"
  }

  // MARK: - Coding Keys

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case city
    case state
    case website
  }

  // MARK: - Hashable

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: CollegeSearchResult, rhs: CollegeSearchResult) -> Bool {
    lhs.id == rhs.id
  }
}
