import Foundation

enum UserRole: String, Codable, CaseIterable {
  case parent = "parent"
  case student = "student"
  case player = "player"

  var displayName: String {
    switch self {
    case .parent:
      return "Parent"
    case .student:
      return "Student"
    case .player:
      return "Player"
    }
  }

  var icon: String {
    switch self {
    case .parent:
      return "person.crop.circle"
    case .student:
      return "book"
    case .player:
      return "sportscourt"
    }
  }

  var description: String {
    switch self {
    case .parent:
      return "Manage your family's recruiting profile"
    case .student:
      return "Build your recruiting profile and connect with coaches"
    case .player:
      return "Track your athletic performance and recruiting status"
    }
  }

  var requiresFamilyCode: Bool {
    self == .student || self == .player
  }
}
