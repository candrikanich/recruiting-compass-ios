//
//  NcaaSchoolInfo.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Model for NCAA school information from bundled database
//

import Foundation

/// NCAA school information for division/conference lookup
struct NcaaSchoolInfo: Codable, Sendable {
  let name: String
  let conference: String
  let logo: String?

  enum CodingKeys: String, CodingKey {
    case name
    case conference
    case logo
  }
}

/// Result of NCAA division/conference lookup
struct NcaaLookupResult: Sendable {
  let division: Division
  let conference: String
  let logo: String?

  nonisolated init(division: Division, conference: String, logo: String? = nil) {
    self.division = division
    self.conference = conference
    self.logo = logo
  }
}
