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
  let conference: String?  // Optional: some entries in the JSON have null conference
  let logo: String?

  enum CodingKeys: String, CodingKey {
    case name
    case conference
    case logo
  }
}
