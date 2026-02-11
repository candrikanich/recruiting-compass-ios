//
//  DuplicateResult.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11.
//

import SwiftUI

/// Result of duplicate school detection
struct DuplicateResult: Sendable {
  let duplicate: School?
  let matchType: DuplicateMatchType?

  var isDuplicate: Bool {
    duplicate != nil
  }
}

/// Type of duplicate match detected
enum DuplicateMatchType: String, CaseIterable, Sendable {
  case name = "name"
  case domain = "domain"
  case ncaaId = "ncaa_id"

  var displayLabel: String {
    switch self {
    case .name: return "Name Match"
    case .domain: return "Website Domain"
    case .ncaaId: return "NCAA ID"
    }
  }

  var badgeColor: Color {
    switch self {
    case .name: return .red
    case .domain: return .yellow
    case .ncaaId: return .orange
    }
  }

  var priority: Int {
    switch self {
    case .name: return 1      // Highest priority
    case .domain: return 2
    case .ncaaId: return 3     // Lowest priority
    }
  }
}
