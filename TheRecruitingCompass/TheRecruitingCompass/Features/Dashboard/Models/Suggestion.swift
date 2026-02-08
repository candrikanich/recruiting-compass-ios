import Foundation
import SwiftUI

struct Suggestion: Codable, Identifiable, Sendable {
  let id: String
  let title: String
  let description: String
  let urgency: UrgencyLevel
  let actionUrl: String?
  let location: String
  let createdAt: String

  enum UrgencyLevel: String, Codable, Sendable {
    case high, medium, low

    var color: Color {
      switch self {
      case .high: return .errorRed
      case .medium: return .warningOrange
      case .low: return .accentBlue
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case description
    case urgency
    case actionUrl = "action_url"
    case location
    case createdAt = "created_at"
  }
}
