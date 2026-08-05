import Foundation

enum SortDirection: String, CaseIterable, Sendable {
  case ascending
  case descending

  var displayName: String {
    switch self {
    case .ascending: return String(localized: "Ascending")
    case .descending: return String(localized: "Descending")
    }
  }
}
