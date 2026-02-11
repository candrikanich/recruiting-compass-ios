//
//  CoachCreateRequest+Preparation.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 2: Validation System - Data preparation for coach creation
//

import Foundation

extension CoachCreateRequest {

  /// Creates a CoachCreateRequest from form state with proper sanitization
  /// Applies all necessary data transformations and sanitization
  /// - Parameters:
  ///   - form: The form state containing user input
  ///   - schoolId: The selected school ID
  ///   - userId: The current user ID
  ///   - familyUnitId: The family unit ID
  /// - Returns: CoachCreateRequest ready for API submission
  static func from(
    form: CoachFormState,
    schoolId: String,
    userId: String,
    familyUnitId: String
  ) -> CoachCreateRequest {
    // Required: role (already validated as non-nil)
    let role = form.role!.rawValue

    // Required: names (trim whitespace)
    let firstName = form.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let lastName = form.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

    // Optional: email (trim, lowercase, nil if empty)
    let email = DataSanitizer.nilIfEmpty(
      form.email
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    )

    // Optional: phone (nil if empty)
    let phone = DataSanitizer.nilIfEmpty(form.phone)

    // Optional: social handles (strip @, nil if empty)
    let twitterHandle = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripAtSign(form.twitterHandle)
    )
    let instagramHandle = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripAtSign(form.instagramHandle)
    )

    // Optional: notes (strip HTML, nil if empty)
    let notes = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripHtmlTags(form.notes)
    )

    return CoachCreateRequest(
      schoolId: schoolId,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      notes: notes
    )
  }
}
