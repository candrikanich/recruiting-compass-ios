import Foundation

enum EventSource: String, CaseIterable, Codable, Sendable {
  case email
  case flyer
  case webSearch = "web_search"
  case recommendation
  case friend
  case other

  var displayName: String {
    switch self {
    case .email: return String(localized: "Email")
    case .flyer: return String(localized: "Flyer")
    case .webSearch: return String(localized: "Web Search")
    case .recommendation: return String(localized: "Recommendation")
    case .friend: return String(localized: "Friend")
    case .other: return String(localized: "Other")
    }
  }
}
