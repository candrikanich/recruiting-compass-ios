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

    var displayName: String {
      switch self {
      case .high: return String(localized: "High")
      case .medium: return String(localized: "Medium")
      case .low: return String(localized: "Low")
      }
    }

    /// Sort priority: high surfaces first.
    var sortWeight: Int {
      switch self {
      case .high: return 0
      case .medium: return 1
      case .low: return 2
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
