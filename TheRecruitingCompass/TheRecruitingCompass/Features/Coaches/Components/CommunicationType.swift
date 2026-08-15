import SwiftUI

enum CommunicationType: Sendable {
  case email(String)
  case phone(String)
  case call(String)
  case twitter(String)
  case instagram(String)

  var iconName: String {
    switch self {
    case .email: return "envelope.fill"
    case .phone: return "message.fill"
    case .call: return "phone.fill"
    case .twitter: return "at"
    // twitter/instagram render their brand asset; this is an unreached fallback.
    case .instagram: return "link"
    }
  }

  /// Bundled brand-mark asset (template-rendered) used instead of an SF Symbol,
  /// nil for types that use `iconName`.
  var brandAssetName: String? {
    switch self {
    case .twitter: return "LogoX"
    case .instagram: return "LogoInstagram"
    case .email, .phone, .call: return nil
    }
  }

  var iconColor: Color {
    switch self {
    case .email: return .accentBlue
    case .phone: return .successGreen
    case .call: return Color.Brand.purple600
    case .twitter: return Color.Brand.slate700
    case .instagram: return Color.Brand.pink500
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .email: return String(localized: "Email coach")
    case .phone: return String(localized: "Text coach")
    case .call: return String(localized: "Call coach")
    case .twitter: return String(localized: "View Twitter profile")
    case .instagram: return String(localized: "View Instagram profile")
    }
  }

  var appName: String {
    switch self {
    case .email: return "Mail"
    case .phone: return "Messages"
    case .call: return "Phone"
    case .twitter: return "Twitter"
    case .instagram: return "Instagram"
    }
  }

  func url(for value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    switch self {
    case .email:
      guard trimmed.contains("@") else { return nil }
      return URL(string: "mailto:\(trimmed)")
    case .phone:
      let cleaned = cleanPhoneNumber(trimmed)
      return URL(string: "sms:\(cleaned)")
    case .call:
      let cleaned = cleanPhoneNumber(trimmed)
      return URL(string: "tel:\(cleaned)")
    case .twitter:
      let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
      return URL(string: "https://twitter.com/\(handle)")
    case .instagram:
      let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
      return URL(string: "https://instagram.com/\(handle)")
    }
  }

  /// Removes formatting characters from phone numbers (spaces, parentheses, dashes)
  /// Keeps only digits and + for country code
  private func cleanPhoneNumber(_ phone: String) -> String {
    phone.filter { $0.isNumber || $0 == "+" }
  }
}
