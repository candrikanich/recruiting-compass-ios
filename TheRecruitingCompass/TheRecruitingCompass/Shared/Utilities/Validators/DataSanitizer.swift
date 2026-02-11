//
//  DataSanitizer.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 2: Validation System - Data sanitization utilities
//

import Foundation

enum DataSanitizer {

  // MARK: - String Sanitization

  /// Converts empty strings to nil for optional database fields
  /// - Parameter value: The string value to check
  /// - Returns: nil if empty, the original value if not empty
  static func nilIfEmpty(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Strips leading @ from social media handles
  /// - Parameter handle: The social media handle (may start with @)
  /// - Returns: The handle without leading @
  static func stripAtSign(_ handle: String) -> String {
    let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
  }

  /// Strips HTML tags from text (basic implementation)
  /// Prevents XSS attacks by removing HTML markup
  /// - Parameter text: The text that may contain HTML tags
  /// - Returns: The text with HTML tags removed
  static func stripHtmlTags(_ text: String) -> String {
    text.replacingOccurrences(
      of: "<[^>]+>",
      with: "",
      options: .regularExpression
    )
  }

}
