import SwiftUI

enum DeadlineCategory: String, Codable, Sendable, CaseIterable, Identifiable {
  case application
  case decision
  case financial_aid
  case visit
  case custom

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .application:   return String(localized: "Application")
    case .decision:      return String(localized: "Decision")
    case .financial_aid: return String(localized: "Financial Aid")
    case .visit:         return String(localized: "Visit")
    case .custom:        return String(localized: "Custom")
    }
  }

  var icon: String {
    switch self {
    case .application:   return "doc.text"
    case .decision:      return "checkmark.seal"
    case .financial_aid: return "dollarsign.circle"
    case .visit:         return "mappin.and.ellipse"
    case .custom:        return "tag"
    }
  }

  var color: Color {
    switch self {
    case .application:   return .blue
    case .decision:      return .green
    case .financial_aid: return .orange
    case .visit:         return .purple
    case .custom:        return .gray
    }
  }
}
