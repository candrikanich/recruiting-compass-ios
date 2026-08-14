import SwiftUI

enum TemplateType: String, Codable, CaseIterable, Sendable {
  case email
  case message
  case social
  case unknown

  /// Types offered in pickers/filters. Excludes `.unknown` (decode-only fallback).
  static var selectable: [TemplateType] { [.email, .message, .social] }

  /// Fail-soft decode: DB uses email/message/social; legacy iOS rows used text/twitter.
  /// Any unrecognized string becomes `.unknown` so one bad row can't throw the array decode.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "email": self = .email
    case "message", "text": self = .message
    case "social", "twitter": self = .social
    default: self = .unknown
    }
  }

  var displayName: String {
    switch self {
    case .email: return String(localized: "Email")
    case .message: return String(localized: "Text")
    case .social: return String(localized: "Social")
    case .unknown: return String(localized: "Other")
    }
  }

  var color: Color {
    switch self {
    case .email: return .accentBlue
    case .message: return .successGreen
    case .social: return .cyan
    case .unknown: return .gray
    }
  }
}
