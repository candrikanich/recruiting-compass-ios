import Foundation

enum Gender: String, Codable, CaseIterable, Sendable {
  case male
  case female
  case other
  case preferNotToSay = "prefer_not_to_say"

  var displayName: String {
    switch self {
    case .male:
      return String(localized: "Male")
    case .female:
      return String(localized: "Female")
    case .other:
      return String(localized: "Other")
    case .preferNotToSay:
      return String(localized: "Prefer not to say")
    }
  }
}
