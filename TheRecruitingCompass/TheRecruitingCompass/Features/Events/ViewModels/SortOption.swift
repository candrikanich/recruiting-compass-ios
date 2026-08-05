import Foundation

enum SortOption: String, CaseIterable {
  case dateDesc = "Date (Newest First)"
  case dateAsc = "Date (Oldest First)"
  case name = "Name"
  case type = "Type"

  var displayName: String {
    switch self {
    case .dateDesc: return String(localized: "Date (Newest First)")
    case .dateAsc: return String(localized: "Date (Oldest First)")
    case .name: return String(localized: "Name")
    case .type: return String(localized: "Type")
    }
  }
}
