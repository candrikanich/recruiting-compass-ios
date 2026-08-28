import Foundation

struct SchoolFilters: Sendable {
  var searchText: String = ""
  var division: Division?
  var status: SchoolStatus?
  var state: String?
  var isFavoritesOnly: Bool = false
  var maxDistance: Double?
  var sortBy: SchoolSortOption = .nameAZ

  var activeFilterCount: Int {
    var count = 0
    if !searchText.isEmpty { count += 1 }
    if division != nil { count += 1 }
    if status != nil { count += 1 }
    if state != nil { count += 1 }
    if isFavoritesOnly { count += 1 }
    if maxDistance != nil { count += 1 }
    return count
  }
}
