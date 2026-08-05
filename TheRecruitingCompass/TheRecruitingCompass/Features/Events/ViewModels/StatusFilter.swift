import Foundation

enum StatusFilter: String, CaseIterable {
  case all = "All"
  case attended = "Attended"
  case registered = "Registered"
  case notRegistered = "Not Registered"
}
