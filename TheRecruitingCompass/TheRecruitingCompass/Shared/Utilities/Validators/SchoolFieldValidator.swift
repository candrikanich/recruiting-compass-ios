//
//  SchoolFieldValidator.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 2: Validation System - School-specific field validators
//

import Foundation

enum SchoolFieldValidator {

  // MARK: - Regex Patterns

  // URL regex pattern (http/https)
  private static let urlPattern = "^https?://[A-Za-z0-9\\-._~:/?#\\[\\]@!$&'()*+,;=%]+$"

  private static let urlRegex: NSRegularExpression = try! NSRegularExpression(pattern: urlPattern)

  // MARK: - Name Validation

  /// Validates school name (required, 2-255 characters)
  /// - Parameter name: The school name to validate
  /// - Returns: Error message if invalid, nil if valid
  static func validateName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      return "School name is required"
    }

    if trimmed.count < 2 {
      return "School name must be at least 2 characters"
    }

    if trimmed.count > 255 {
      return "School name must not exceed 255 characters"
    }

    return nil
  }

  // MARK: - Location Validation

  /// Validates location field (optional, max 255 characters)
  /// - Parameter location: The location text to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateLocation(_ location: String) -> String? {
    // Empty is valid (optional field)
    guard !location.isEmpty else {
      return nil
    }

    if location.count > 255 {
      return "Location must not exceed 255 characters"
    }

    return nil
  }

  /// Validates city field (optional, max 100 characters)
  /// - Parameter city: The city name to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateCity(_ city: String) -> String? {
    // Empty is valid (optional field)
    guard !city.isEmpty else {
      return nil
    }

    if city.count > 100 {
      return "City must not exceed 100 characters"
    }

    return nil
  }

  /// Validates state field (optional, max 100 characters)
  /// - Parameter state: The state name to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateState(_ state: String) -> String? {
    // Empty is valid (optional field)
    guard !state.isEmpty else {
      return nil
    }

    if state.count > 100 {
      return "State must not exceed 100 characters"
    }

    return nil
  }

  // MARK: - Conference Validation

  /// Validates conference field (optional, max 100 characters)
  /// - Parameter conference: The conference name to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateConference(_ conference: String) -> String? {
    // Empty is valid (optional field)
    guard !conference.isEmpty else {
      return nil
    }

    if conference.count > 100 {
      return "Conference must not exceed 100 characters"
    }

    return nil
  }

  // MARK: - Website Validation

  /// Validates website URL (optional, but if provided must be valid)
  /// Requires http:// or https:// protocol
  /// - Parameter website: The website URL to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateWebsite(_ website: String) -> String? {
    let trimmed = website.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty is valid (optional field)
    guard !trimmed.isEmpty else {
      return nil
    }

    if trimmed.count > 500 {
      return "Website URL must not exceed 500 characters"
    }

    // Validate URL format using regex
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard urlRegex.firstMatch(in: trimmed, range: range) != nil else {
      return "Please enter a valid URL (must start with http:// or https://)"
    }

    return nil
  }

  // MARK: - Reusable Validators

  /// Validates Twitter handle by delegating to FieldValidator
  /// - Parameter handle: The Twitter handle to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateTwitterHandle(_ handle: String) -> String? {
    FieldValidator.validateTwitterHandle(handle)
  }

  /// Validates Instagram handle by delegating to FieldValidator
  /// - Parameter handle: The Instagram handle to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateInstagramHandle(_ handle: String) -> String? {
    FieldValidator.validateInstagramHandle(handle)
  }

  /// Validates notes field by delegating to FieldValidator
  /// - Parameter notes: The notes text to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateNotes(_ notes: String) -> String? {
    FieldValidator.validateNotes(notes)
  }

}
