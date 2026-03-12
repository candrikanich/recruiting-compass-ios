import Foundation
import SwiftUI

/// Result of fit score calculation
struct FitScoreResult: Codable, Sendable {
  let score: Double
  let tier: FitTier
  let breakdown: FitScoreBreakdown
  let missingDimensions: [String]
}

/// Breakdown of fit score by dimension
struct FitScoreBreakdown: Codable, Sendable {
  let athleticFit: Double?
  let academicFit: Double?
  let opportunityFit: Double?
  let personalFit: Double?
}

/// Tier classification for fit score
enum FitTier: String, Codable, CaseIterable, Sendable {
  case reach
  case match
  case safety
  case unlikely

  var displayName: String {
    switch self {
    case .reach: return "Reach"
    case .match: return "Match"
    case .safety: return "Safety"
    case .unlikely: return "Unlikely"
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .reach: return .orange
    case .match: return .emerald
    case .safety: return .emerald
    case .unlikely: return .red
    }
  }

  var description: String {
    switch self {
    case .reach:
      return "This school is a reach - admission is competitive"
    case .match:
      return "This school is a good match for your profile"
    case .safety:
      return "This school is a safety - high likelihood of admission"
    case .unlikely:
      return "This school may be outside your target range"
    }
  }
}

/// Division recommendation based on fit score
struct DivisionRecommendation: Sendable {
  let shouldConsiderOtherDivisions: Bool
  let recommendedDivisions: [String]
  let message: String
}
