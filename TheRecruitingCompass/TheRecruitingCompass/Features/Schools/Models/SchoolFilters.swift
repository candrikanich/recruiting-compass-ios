import Foundation

struct SchoolFilters: Sendable {
  var searchText: String = ""
  var division: Division?
  var status: SchoolStatus?
  var state: String?
  var isFavoritesOnly: Bool = false
  var fitScoreMin: Double?
  var fitScoreMax: Double?
  var maxDistance: Double?
  var sortBy: SchoolSortOption = .nameAZ
}

enum SchoolSortOption: String, CaseIterable, Sendable {
  case nameAZ = "name_az"
  case fitScore = "fit_score"
  case distance
  case lastContact = "last_contact"

  var displayName: String {
    switch self {
    case .nameAZ:
      return "Name (A-Z)"
    case .fitScore:
      return "Fit Score"
    case .distance:
      return "Distance"
    case .lastContact:
      return "Last Contact"
    }
  }
}
