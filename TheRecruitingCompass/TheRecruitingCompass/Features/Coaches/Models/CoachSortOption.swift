import Foundation

enum CoachSortOption: String, CaseIterable, Sendable {
  case name
  case school
  case lastContacted
  case role

  var displayName: String {
    switch self {
    case .name: return String(localized: "Name")
    case .school: return String(localized: "School")
    case .lastContacted: return String(localized: "Last Contacted")
    case .role: return String(localized: "Role")
    }
  }
}
