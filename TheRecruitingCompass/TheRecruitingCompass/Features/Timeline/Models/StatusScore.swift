import Foundation
import SwiftUI

/// Status label derived from score (on_track / slightly_behind / at_risk).
enum StatusLabel: String, Codable, Sendable {
  case onTrack = "on_track"
  case slightlyBehind = "slightly_behind"
  case atRisk = "at_risk"
}

/// Composite status score result (0–100, label, optional breakdown).
struct StatusScore: Sendable {
  let score: Int
  let label: StatusLabel
  let breakdown: StatusScoreBreakdown?

  init(score: Int, label: StatusLabel, breakdown: StatusScoreBreakdown? = nil) {
    self.score = min(100, max(0, score))
    self.label = label
    self.breakdown = breakdown
  }

  var color: Color {
    switch label {
    case .onTrack: return .successGreen
    case .slightlyBehind: return Color(hex: "F59E0B")
    case .atRisk: return .errorRed
    }
  }
}

struct StatusScoreBreakdown: Sendable {
  let taskCompletionRate: Double
  let interactionFrequencyScore: Double
  let coachInterestScore: Double
  let academicStandingScore: Double
}
