import Foundation

struct CoachFilters: Equatable, Sendable {
  var searchText: String = ""
  var role: CoachRole?
  var lastContactDays: Int?
  var schoolId: String?
  var sortBy: CoachSortOption = .name

  var hasActiveFilters: Bool {
    role != nil || lastContactDays != nil || schoolId != nil
  }

  var activeFilterCount: Int {
    var count = 0
    if role != nil { count += 1 }
    if lastContactDays != nil { count += 1 }
    if schoolId != nil { count += 1 }
    return count
  }
}
