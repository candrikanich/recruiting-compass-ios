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
