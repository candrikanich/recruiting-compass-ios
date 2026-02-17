import Foundation

enum EventType: String, CaseIterable, Codable, Sendable {
  case showcase
  case camp
  case officialVisit = "official_visit"
  case unofficialVisit = "unofficial_visit"
  case game

  var displayName: String {
    switch self {
    case .showcase: return "Showcase"
    case .camp: return "Camp"
    case .officialVisit: return "Official Visit"
    case .unofficialVisit: return "Unofficial Visit"
    case .game: return "Game"
    }
  }
}
