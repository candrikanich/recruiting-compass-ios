import Foundation

/// Pure domain: list-level school stats from the full (unfiltered) set.
struct ComputeSchoolAnalyticsUseCase: Sendable {

  func execute(
    schools: [School],
    visitedSchoolIds: Set<String>,
    contactedSchoolIds: Set<String>
  ) -> SchoolAnalytics {
    var favorites = 0
    var visited = 0
    var contacted = 0
    for school in schools {
      if school.isFavorite { favorites += 1 }
      if visitedSchoolIds.contains(school.id) { visited += 1 }
      if contactedSchoolIds.contains(school.id) { contacted += 1 }
    }
    return SchoolAnalytics(
      totalCount: schools.count,
      favoritesCount: favorites,
      visitedCount: visited,
      contactedCount: contacted
    )
  }
}
