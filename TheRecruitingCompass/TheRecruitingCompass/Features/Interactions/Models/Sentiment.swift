import Foundation

enum Sentiment: String, Codable, CaseIterable, Sendable {
  case veryPositive = "very_positive"
  case positive
  case neutral
  case negative
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = Sentiment(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable values. Excludes `unknown`: a decode-only fallback for server values this build lacks.
  static var selectableCases: [Sentiment] {
    allCases.filter { $0 != .unknown }
  }

  var displayName: String {
    switch self {
    case .veryPositive: return String(localized: "Very Positive")
    case .positive: return String(localized: "Positive")
    case .neutral: return String(localized: "Neutral")
    case .negative: return String(localized: "Negative")
    case .unknown: return String(localized: "Unknown")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .veryPositive: return .emerald
    case .positive:     return .blue
    case .neutral:      return .slate
    case .negative:     return .red
    case .unknown:      return .slate
    }
  }

  var isPositive: Bool {
    self == .veryPositive || self == .positive
  }
}
