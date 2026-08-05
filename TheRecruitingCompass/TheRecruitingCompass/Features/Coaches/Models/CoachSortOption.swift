import Foundation

enum CoachSortOption: String, CaseIterable, Sendable {
  case name
  case school
  case lastContacted
  case role

  var displayName: String {
    switch self {
    case .name: return "Name"
    case .school: return "School"
    case .lastContacted: return "Last Contacted"
    case .role: return "Role"
    }
  }
}
