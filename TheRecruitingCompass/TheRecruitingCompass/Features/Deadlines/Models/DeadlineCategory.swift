import SwiftUI

enum DeadlineCategory: String, Codable, Sendable, CaseIterable, Identifiable {
  case application
  case decision
  case financial_aid
  case visit
  case custom
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = DeadlineCategory(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable values. Excludes `unknown`: a decode-only fallback for server values this build lacks.
  static var selectableCases: [DeadlineCategory] {
    allCases.filter { $0 != .unknown }
  }

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .application:   return String(localized: "Application")
    case .decision:      return String(localized: "Decision")
    case .financial_aid: return String(localized: "Financial Aid")
    case .visit:         return String(localized: "Visit")
    case .custom:        return String(localized: "Custom")
    case .unknown:       return String(localized: "Unknown")
    }
  }

  var icon: String {
    switch self {
    case .application:   return "doc.text"
    case .decision:      return "checkmark.seal"
    case .financial_aid: return "dollarsign.circle"
    case .visit:         return "mappin.and.ellipse"
    case .custom:        return "tag"
    case .unknown:       return "questionmark.circle"
    }
  }

  var color: Color {
    switch self {
    case .application:   return Color.accentPrimary
    case .decision:      return .green
    case .financial_aid: return .orange
    case .visit:         return Color.Category.gold
    case .custom:        return .gray
    case .unknown:       return .gray
    }
  }
}
