//
//  DuplicateResult.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11.
//

import Foundation

/// Result of duplicate school detection
struct DuplicateResult: Sendable {
  let duplicate: School?
  let matchType: DuplicateMatchType?

  var isDuplicate: Bool {
    duplicate != nil
  }
}
