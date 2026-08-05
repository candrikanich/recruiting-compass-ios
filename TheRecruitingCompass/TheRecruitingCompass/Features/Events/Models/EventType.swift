import Foundation

enum EventType: String, CaseIterable, Codable, Sendable {
  case showcase
  case camp
  case officialVisit = "official_visit"
  case unofficialVisit = "unofficial_visit"
  case game

  var displayName: String {
    switch self {
    case .showcase: return String(localized: "Showcase")
    case .camp: return String(localized: "Camp")
    case .officialVisit: return String(localized: "Official Visit")
    case .unofficialVisit: return String(localized: "Unofficial Visit")
    case .game: return String(localized: "Game")
    }
  }
}
