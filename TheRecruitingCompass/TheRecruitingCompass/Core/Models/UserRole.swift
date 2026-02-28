import Foundation

enum UserRole: String, Codable, CaseIterable {
  case parent = "parent"
  case player = "player"

  var displayName: String {
    switch self {
    case .parent:
      return "Parent"
    case .player:
      return "Player"
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
      return "Manage your family's recruiting profile"
    case .player:
      return "Track your athletic performance and recruiting status"
    }
  }

  /// Parent joins an existing family using a code from their player child.
  /// Player creates the family and generates the code; no field on signup.
  var requiresFamilyCode: Bool {
    self == .parent
  }
}
