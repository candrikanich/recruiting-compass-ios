import SwiftUI

enum TemplateType: String, Codable, CaseIterable, Sendable {
  case email
  case text
  case twitter

  var displayName: String {
    switch self {
    case .email: return "Email"
    case .text: return "Text"
    case .twitter: return "Twitter"
    }
  }

  var color: Color {
    switch self {
    case .email: return .accentBlue
    case .text: return .successGreen
    case .twitter: return .cyan
    }
  }
}
