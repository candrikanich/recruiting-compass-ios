//
//  SchoolCreateRequest+Preparation.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 2: Validation System - Data preparation for school creation
//

import Foundation

extension SchoolCreateRequest {

  /// Creates a SchoolCreateRequest from form state with proper sanitization
  /// Applies all necessary data transformations and sanitization
  /// - Parameters:
  ///   - form: The form state containing user input
  ///   - scorecardData: Optional College Scorecard API data (nil in MVP)
  ///   - userId: The current user ID
  ///   - familyUnitId: The family unit ID
  /// - Returns: SchoolCreateRequest ready for API submission
  static func from(
    form: SchoolFormState,
    scorecardData: CollegeDataResult? = nil,
    userId: String,
    familyUnitId: String
  ) -> SchoolCreateRequest {
    // Required: name (trim whitespace)
    let name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)

    // Optional: location (trim, nil if empty)
    let location = DataSanitizer.nilIfEmpty(form.location)

    // Optional: city (trim, nil if empty)
    let city = DataSanitizer.nilIfEmpty(form.city)

    // Optional: state (trim, nil if empty)
    let state = DataSanitizer.nilIfEmpty(form.state)

    // Optional: division (convert to rawValue if present)
    let division = form.division?.rawValue

    // Optional: conference (trim, nil if empty)
    let conference = DataSanitizer.nilIfEmpty(form.conference)

    // Optional: website (trim, nil if empty)
    let website = DataSanitizer.nilIfEmpty(
      form.website.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    // Optional: social handles (strip @, nil if empty)
    let twitterHandle = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripAtSign(form.twitterHandle)
    )
    let instagramHandle = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripAtSign(form.instagramHandle)
    )

    // Optional: NCAA ID (from Scorecard data in fast-follow, nil in MVP)
    let ncaaId: String? = nil

    // Optional: notes (strip HTML, nil if empty)
    let notes = DataSanitizer.nilIfEmpty(
      DataSanitizer.stripHtmlTags(form.notes)
    )

    // Required: status (convert to rawValue)
    let status = form.status.rawValue

    // Optional: academic info (from Scorecard data in fast-follow, nil in MVP)
    let academicInfo: AcademicInfo? = nil

    return SchoolCreateRequest(
      userId: userId,
      familyUnitId: familyUnitId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      website: website,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      notes: notes,
      status: status,
      academicInfo: academicInfo
    )
  }
}
