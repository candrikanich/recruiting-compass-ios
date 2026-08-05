import Foundation

enum DocumentSortOption: String, CaseIterable {
  case newest = "newest"
  case oldest = "oldest"
  case name = "name"
  case type = "type"
  case shared = "shared"

  var label: String {
    switch self {
    case .newest: return String(localized: "Newest First")
    case .oldest: return String(localized: "Oldest First")
    case .name: return String(localized: "Name (A-Z)")
    case .type: return String(localized: "Type")
    case .shared: return String(localized: "Most Shared")
    }
  }
}
