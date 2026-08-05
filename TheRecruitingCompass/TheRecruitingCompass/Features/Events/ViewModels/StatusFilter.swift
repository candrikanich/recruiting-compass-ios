import Foundation

enum StatusFilter: String, CaseIterable {
  case all = "All"
  case attended = "Attended"
  case registered = "Registered"
  case notRegistered = "Not Registered"

  var displayName: String {
    switch self {
    case .all: return String(localized: "All")
    case .attended: return String(localized: "Attended")
    case .registered: return String(localized: "Registered")
    case .notRegistered: return String(localized: "Not Registered")
    }
  }
}
