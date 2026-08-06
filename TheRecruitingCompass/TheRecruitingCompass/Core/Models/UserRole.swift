import Foundation

enum UserRole: String, Codable, CaseIterable, Sendable {
  case parent
  case player

  var displayName: String {
    switch self {
    case .parent:
      return String(localized: "Parent")
    case .player:
      return String(localized: "Player")
    }
  }

  var icon: String {
    switch self {
    case .parent:
      return "person.crop.circle"
    case .player:
      return "sportscourt"
    }
  }

  var description: String {
    switch self {
    case .parent:
      return String(localized: "Manage your family's recruiting profile")
    case .player:
      return String(localized: "Track your athletic performance and recruiting status")
    }
  }

  /// Both roles create their own family at signup; neither requires a family code at signup.
  /// Parents join additional families via code in Family Management; players invite parents via email.
  var requiresFamilyCode: Bool {
    false
  }
}
