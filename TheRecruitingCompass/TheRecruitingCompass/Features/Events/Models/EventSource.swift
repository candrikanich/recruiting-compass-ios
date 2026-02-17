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
    case .email: return "Email"
    case .flyer: return "Flyer"
    case .webSearch: return "Web Search"
    case .recommendation: return "Recommendation"
    case .friend: return "Friend"
    case .other: return "Other"
    }
  }
}
