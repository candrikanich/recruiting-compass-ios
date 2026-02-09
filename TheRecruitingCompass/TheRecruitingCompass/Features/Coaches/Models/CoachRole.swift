import SwiftUI

enum CoachRole: String, Codable, CaseIterable, Sendable {
  case head = "head"
  case assistant = "assistant"
  case recruiting = "recruiting"

  var displayName: String {
    switch self {
    case .head: return "Head Coach"
    case .assistant: return "Assistant Coach"
    case .recruiting: return "Recruiting Coordinator"
    }
  }

  var badgeColor: Color {
    switch self {
    case .head: return .accentBlue
    case .assistant: return .successGreen
    case .recruiting: return .amberGold
    }
  }
}
