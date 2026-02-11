//
//  FieldValidator.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 2: Validation System - Reusable field validators
//

import Foundation

enum FieldValidator {

  // MARK: - Regex Patterns

  private static let emailPattern = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
  private static let phonePattern = "^\\(?([0-9]{3})\\)?[\\-. ]?([0-9]{3})[\\-. ]?([0-9]{4})$"
  private static let twitterPattern = "^[A-Za-z0-9_]{1,15}$"
  private static let instagramPattern = "^[A-Za-z0-9_.]{1,30}$"

  // MARK: - Role Validation

  /// Validates that a role is selected
  /// - Parameter role: The role to validate (optional)
  /// - Returns: Error message if invalid, nil if valid
  static func validateRole(_ role: String?) -> String? {
    guard role != nil else {
      return "Please select a role"
    }
    return nil
  }

  // MARK: - Name Validation

  /// Validates first name (required, 1-100 characters)
  /// - Parameter name: The first name to validate
  /// - Returns: Error message if invalid, nil if valid
  static func validateFirstName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      return "First name is required"
    }

    if trimmed.count > 100 {
      return "First name must not exceed 100 characters"
    }

    return nil
  }

  /// Validates last name (required, 1-100 characters)
  /// - Parameter name: The last name to validate
  /// - Returns: Error message if invalid, nil if valid
  static func validateLastName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      return "Last name is required"
    }

    if trimmed.count > 100 {
      return "Last name must not exceed 100 characters"
    }

    return nil
  }

  // MARK: - Contact Info Validation

  /// Validates email address (optional field, but if provided must be valid)
  /// - Parameter email: The email to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateEmail(_ email: String) -> String? {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty is valid (optional field)
    guard !trimmed.isEmpty else {
      return nil
    }

    if trimmed.count < 5 {
      return "Email must be at least 5 characters"
    }

    if trimmed.count > 255 {
      return "Email must not exceed 255 characters"
    }

    // Validate email format using regex
    let regex = try! NSRegularExpression(pattern: emailPattern)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard regex.firstMatch(in: trimmed, range: range) != nil else {
      return "Please enter a valid email address"
    }

    return nil
  }

  /// Validates phone number (optional field, but if provided must be valid)
  /// Accepts formats: (555) 123-4567, 555-123-4567, 555.123.4567, 5551234567
  /// - Parameter phone: The phone number to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validatePhone(_ phone: String) -> String? {
    let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty is valid (optional field)
    guard !trimmed.isEmpty else {
      return nil
    }

    // Validate phone format using regex
    let regex = try! NSRegularExpression(pattern: phonePattern)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard regex.firstMatch(in: trimmed, range: range) != nil else {
      return "Please enter a valid phone number"
    }

    return nil
  }

  // MARK: - Social Media Validation

  /// Validates Twitter handle (optional, 1-15 chars, letters/numbers/underscore)
  /// Automatically strips leading @ if present
  /// - Parameter handle: The Twitter handle to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateTwitterHandle(_ handle: String) -> String? {
    let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty is valid (optional field)
    guard !trimmed.isEmpty else {
      return nil
    }

    // Strip @ if present
    let cleaned = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

    // Validate Twitter handle format using regex
    let regex = try! NSRegularExpression(pattern: twitterPattern)
    let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)

    guard regex.firstMatch(in: cleaned, range: range) != nil else {
      return "Invalid Twitter handle (1-15 characters, letters/numbers/underscore)"
    }

    return nil
  }

  /// Validates Instagram handle (optional, 1-30 chars, letters/numbers/dots/underscore)
  /// Automatically strips leading @ if present
  /// - Parameter handle: The Instagram handle to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateInstagramHandle(_ handle: String) -> String? {
    let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty is valid (optional field)
    guard !trimmed.isEmpty else {
      return nil
    }

    // Strip @ if present
    let cleaned = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

    // Validate Instagram handle format using regex
    let regex = try! NSRegularExpression(pattern: instagramPattern)
    let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)

    guard regex.firstMatch(in: cleaned, range: range) != nil else {
      return "Invalid Instagram handle (1-30 characters, letters/numbers/dots/underscore)"
    }

    return nil
  }

  // MARK: - Notes Validation

  /// Validates notes field (optional, max 5000 characters)
  /// - Parameter notes: The notes text to validate
  /// - Returns: Error message if invalid, nil if valid or empty
  static func validateNotes(_ notes: String) -> String? {
    // Empty is valid (optional field)
    guard !notes.isEmpty else {
      return nil
    }

    if notes.count > 5000 {
      return "Notes must not exceed 5000 characters"
    }

    return nil
  }

}
