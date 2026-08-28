import CoreLocation
import Foundation

/// Pure domain: filter + sort a school list. No I/O, no UI state.
/// Main-actor isolated because callers pass view-model closures (fit + distance cache).
@MainActor
struct FilterAndSortSchoolsUseCase {

  func execute(
    schools: [School],
    filters: SchoolFilters,
    homeLocation: CLLocationCoordinate2D?,
    overallFit: (School) -> OverallPersonalFit?,
    distance: (School, CLLocationCoordinate2D) -> Double?
  ) -> [School] {
    var result = schools

    if !filters.searchText.isEmpty {
      let query = filters.searchText
      result = result.filter { school in
        school.name.localizedStandardContains(query)
          || (school.location?.localizedStandardContains(query) ?? false)
          || (school.city?.localizedStandardContains(query) ?? false)
          || (school.state?.localizedStandardContains(query) ?? false)
          || (school.conference?.localizedStandardContains(query) ?? false)
          || (school.notes?.localizedStandardContains(query) ?? false)
      }
    }

    if let division = filters.division {
      result = result.filter { $0.division == division.rawValue }
    }

    if let status = filters.status {
      result = result.filter { $0.status == status.rawValue }
    }

    if let state = filters.state {
      result = result.filter { $0.state == state }
    }

    if filters.isFavoritesOnly {
      result = result.filter { $0.isFavorite }
    }

    if let maxDistance = filters.maxDistance, let home = homeLocation {
      result = result.filter { school in
        guard let miles = distance(school, home) else { return false }
        return miles <= maxDistance
      }
    }

    return sorted(
      result,
      sortBy: filters.sortBy,
      homeLocation: homeLocation,
      overallFit: overallFit,
      distance: distance
    )
  }

  private func sorted(
    _ schools: [School],
    sortBy: SchoolSortOption,
    homeLocation: CLLocationCoordinate2D?,
    overallFit: (School) -> OverallPersonalFit?,
    distance: (School, CLLocationCoordinate2D) -> Double?
  ) -> [School] {
    switch sortBy {
    case .nameAZ:
      return schools.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    case .personalFit:
      return schools.sorted { rank(overallFit($0)?.strength) > rank(overallFit($1)?.strength) }

    case .distance:
      guard let home = homeLocation else { return schools }
      return schools.sorted { lhs, rhs in
        let lhsDistance = distance(lhs, home) ?? Double.infinity
        let rhsDistance = distance(rhs, home) ?? Double.infinity
        return lhsDistance < rhsDistance
      }

    case .lastContact:
      return schools.sorted { lhs, rhs in
        guard let lhsDate = lhs.statusChangedAt else { return false }
        guard let rhsDate = rhs.statusChangedAt else { return true }
        return lhsDate > rhsDate
      }
    }
  }

  private func rank(_ strength: OverallPersonalFit.Strength?) -> Int {
    switch strength {
    case .strong: return 2
    case .good: return 1
    case .stretch: return 0
    case nil: return -1
    }
  }
}
