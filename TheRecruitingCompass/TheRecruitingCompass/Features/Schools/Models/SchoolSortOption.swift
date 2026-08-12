import Foundation

enum SchoolSortOption: String, CaseIterable, Sendable {
  case nameAZ = "name_az"
  case personalFit = "personal_fit"
  case distance
  case lastContact = "last_contact"

  var displayName: String {
    switch self {
    case .nameAZ:
      return "Name (A-Z)"
    case .personalFit:
      return String(localized: "Personal Fit")
    case .distance:
      return "Distance"
    case .lastContact:
      return "Last Contact"
    }
  }
}
