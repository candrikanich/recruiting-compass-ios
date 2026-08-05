import Foundation

enum DocumentSortOption: String, CaseIterable {
  case newest = "newest"
  case oldest = "oldest"
  case name = "name"
  case type = "type"
  case shared = "shared"

  var label: String {
    switch self {
    case .newest: return "Newest First"
    case .oldest: return "Oldest First"
    case .name: return "Name (A-Z)"
    case .type: return "Type"
    case .shared: return "Most Shared"
    }
  }
}
