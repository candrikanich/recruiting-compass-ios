import Foundation

enum SortDirection: String, CaseIterable, Sendable {
  case ascending
  case descending

  var displayName: String {
    switch self {
    case .ascending: return "Ascending"
    case .descending: return "Descending"
    }
  }
}
