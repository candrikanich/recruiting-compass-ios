import Foundation

enum DashboardDestination: String, Identifiable {
  case coaches
  case schools
  case interactions
  case offers
  case accepted
  case aTier
  case suggestions

  var id: String { rawValue }

  var title: String {
    switch self {
    case .coaches: return "Coaches"
    case .schools: return "Schools"
    case .interactions: return "Interactions"
    case .offers: return "Offers"
    case .accepted: return "Accepted Offers"
    case .aTier: return "A-Tier Schools"
    case .suggestions: return "Action Items"
    }
  }
}
