import Foundation
import SwiftUI

/// Suggestion from GET /api/suggestions (rule-engine driven action items).
struct Suggestion: Codable, Identifiable, Sendable {
  let id: String
  let ruleType: String
  let message: String
  let urgency: UrgencyLevel
  let actionType: String?
  let relatedSchoolId: String?
  let dismissed: Bool
  let completed: Bool
  let pendingSurface: Bool?
  let surfacedAt: String?

  enum UrgencyLevel: String, Codable, Sendable {
    case high
    case medium
    case low

    /// high → red, medium → amber, low → blue (per web handoff)
    var color: Color {
      switch self {
      case .high: return .errorRed
      case .medium: return .amberGold
      case .low: return .accentBlue
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case id
    case message
    case urgency
    case ruleType = "rule_type"
    case actionType = "action_type"
    case relatedSchoolId = "related_school_id"
    case dismissed
    case completed
    case pendingSurface = "pending_surface"
    case surfacedAt = "surfaced_at"
  }
}

/// Response from GET /api/suggestions?location=dashboard
struct SuggestionsResponse: Codable, Sendable {
  let suggestions: [Suggestion]
  let pendingCount: Int

  enum CodingKeys: String, CodingKey {
    case suggestions
    case pendingCount = "pendingCount"
  }
}
