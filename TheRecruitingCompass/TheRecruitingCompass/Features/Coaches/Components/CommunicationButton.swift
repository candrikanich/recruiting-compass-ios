import SwiftUI

struct CommunicationButton: View {
  let type: CommunicationType
  let value: String

  @Environment(\.openURL) private var openURL
  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 24 : 18
  }

  var body: some View {
    Button {
      if let url = type.url(for: value) {
        openURL(url)
      }
    } label: {
      Image(systemName: type.iconName)
        .font(.system(size: iconSize))
        .foregroundStyle(type.iconColor)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(type.accessibilityLabel)
    .accessibilityHint("Opens \(type.appName)")
  }
}

enum CommunicationType: Sendable {
  case email(String)
  case phone(String)
  case twitter(String)
  case instagram(String)

  var iconName: String {
    switch self {
    case .email: return "envelope.fill"
    case .phone: return "message.fill"
    case .twitter: return "at"
    case .instagram: return "camera.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .email: return .accentBlue
    case .phone: return .successGreen
    case .twitter: return Color(hex: "1DA1F2")
    case .instagram: return Color(hex: "E4405F")
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .email: return "Email coach"
    case .phone: return "Text coach"
    case .twitter: return "View Twitter profile"
    case .instagram: return "View Instagram profile"
    }
  }

  var appName: String {
    switch self {
    case .email: return "Mail"
    case .phone: return "Messages"
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
      return URL(string: "sms:\(trimmed)")
    case .twitter:
      let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
      return URL(string: "https://twitter.com/\(handle)")
    case .instagram:
      let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
      return URL(string: "https://instagram.com/\(handle)")
    }
  }
}

#Preview {
  HStack(spacing: 8) {
    CommunicationButton(type: .email("test@example.com"), value: "test@example.com")
    CommunicationButton(type: .phone("555-1234"), value: "555-1234")
    CommunicationButton(type: .twitter("@coach"), value: "@coach")
    CommunicationButton(type: .instagram("@coach"), value: "@coach")
  }
}
