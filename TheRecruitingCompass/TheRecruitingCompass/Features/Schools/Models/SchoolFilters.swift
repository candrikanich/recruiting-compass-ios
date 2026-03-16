import Foundation

struct SchoolFilters: Sendable {
  var searchText: String = ""
  var division: Division? = nil
  var status: SchoolStatus? = nil
  var state: String? = nil
  var isFavoritesOnly: Bool = false
  var fitScoreMin: Double? = nil
  var fitScoreMax: Double? = nil
  var maxDistance: Double? = nil
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
