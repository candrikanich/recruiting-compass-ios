import CoreLocation
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolsListViewModel")

@Observable
@MainActor
final class SchoolsListViewModel {
  var allSchools: [School] = []
  var isLoading = false
  var errorMessage: String?
  var filters = SchoolFilters()
  var showDeleteConfirmation = false
  var schoolToDelete: School?
  var isDeleting = false
  var deleteErrorMessage: String?
  var successMessage: String?
  var showSuccessToast = false
  var homeLocation: CLLocationCoordinate2D?

  private let schoolsService: any SchoolsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging
  private var distanceCache: [String: Double] = [:]

  var filteredSchools: [School] {
    var result = allSchools

    if !filters.searchText.isEmpty {
      let query = filters.searchText.lowercased()
      result = result.filter { school in
        school.name.lowercased().contains(query)
          || (school.location?.lowercased().contains(query) ?? false)
          || (school.city?.lowercased().contains(query) ?? false)
          || (school.state?.lowercased().contains(query) ?? false)
          || (school.conference?.lowercased().contains(query) ?? false)
          || (school.notes?.lowercased().contains(query) ?? false)
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

    if let tier = filters.priorityTier {
      result = result.filter { $0.priorityTier == tier.rawValue }
    }

    if let minScore = filters.fitScoreMin {
      result = result.filter { ($0.fitScore ?? 0) >= minScore }
    }

    if let maxScore = filters.fitScoreMax {
      result = result.filter { ($0.fitScore ?? 100) <= maxScore }
    }

    if let maxDistance = filters.maxDistance, let home = homeLocation {
      result = result.filter { school in
        guard let distance = cachedDistance(for: school, from: home) else { return false }
        return distance <= maxDistance
      }
    }

    return sorted(result)
  }

  var availableStates: [String] {
    let states = allSchools.compactMap { $0.state }
    return Array(Set(states)).sorted()
  }

  var resultCount: Int {
    filteredSchools.count
  }

  var activeFilterCount: Int {
    filters.activeFilterCount
  }

  var showWarningBanner: Bool {
    allSchools.count >= 30
  }

  init(
    schoolsService: (any SchoolsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
  }

  func loadSchools() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load schools. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    distanceCache.removeAll()
    defer { isLoading = false }

    do {
      allSchools = try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
      logger.info("Loaded \(self.allSchools.count) schools")
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      errorMessage = "Failed to load schools. Please try again."
    }
  }

  func confirmDelete(school: School) {
    schoolToDelete = school
    showDeleteConfirmation = true
  }

  func deleteSchool() async {
    guard let school = schoolToDelete else { return }

    isDeleting = true
    deleteErrorMessage = nil
    defer {
      isDeleting = false
      showDeleteConfirmation = false
    }

    do {
      do {
        try await schoolsService.deleteSchool(id: school.id)
        allSchools.removeAll { $0.id == school.id }
        distanceCache.removeValue(forKey: school.id)
        successMessage = "School deleted successfully"
        showSuccessToast = true
        logger.info("School deleted: \(school.name)")
      } catch {
        logger.warning("Simple delete failed, attempting cascade delete: \(error.localizedDescription)")
        let result = try await schoolsService.cascadeDeleteSchool(id: school.id)
        allSchools.removeAll { $0.id == school.id }
        distanceCache.removeValue(forKey: school.id)
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        successMessage = totalDeleted > 0
          ? "School and \(totalDeleted) related items deleted"
          : "School deleted successfully"
        showSuccessToast = true
        logger.info("Cascade delete successful: \(school.name)")
      }
    } catch {
      logger.error("Delete failed: \(error.localizedDescription)")
      deleteErrorMessage = "Failed to delete school. Please try again."
    }
  }

  func toggleFavorite(school: School) async {
    let originalSchool = school
    let newFavoriteState = !school.isFavorite

    if let index = allSchools.firstIndex(where: { $0.id == school.id }) {
      allSchools[index] = school.with(isFavorite: newFavoriteState)
    }

    do {
      try await schoolsService.toggleFavorite(id: school.id, isFavorite: newFavoriteState)
      logger.info("Favorite toggled for school: \(school.name)")
    } catch {
      logger.error("Failed to toggle favorite: \(error.localizedDescription)")

      if let index = allSchools.firstIndex(where: { $0.id == school.id }) {
        allSchools[index] = originalSchool
      }

      errorMessage = "Failed to update favorite. Please try again."
    }
  }

  func clearFilters() {
    filters = SchoolFilters(sortBy: filters.sortBy)
  }

  func cachedDistance(for school: School, from coordinate: CLLocationCoordinate2D) -> Double? {
    if let cached = distanceCache[school.id] {
      return cached
    }

    guard let distance = school.distanceTo(from: coordinate) else {
      return nil
    }

    distanceCache[school.id] = distance
    return distance
  }

  private func sorted(_ schools: [School]) -> [School] {
    switch filters.sortBy {
    case .nameAZ:
      return schools.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    case .fitScore:
      return schools.sorted { ($0.fitScore ?? 0) > ($1.fitScore ?? 0) }

    case .distance:
      guard let home = homeLocation else { return schools }
      return schools.sorted { lhs, rhs in
        let lhsDistance = cachedDistance(for: lhs, from: home) ?? Double.infinity
        let rhsDistance = cachedDistance(for: rhs, from: home) ?? Double.infinity
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
}

extension SchoolFilters {
  var activeFilterCount: Int {
    var count = 0
    if !searchText.isEmpty { count += 1 }
    if division != nil { count += 1 }
    if status != nil { count += 1 }
    if state != nil { count += 1 }
    if isFavoritesOnly { count += 1 }
    if priorityTier != nil { count += 1 }
    if fitScoreMin != nil || fitScoreMax != nil { count += 1 }
    if maxDistance != nil { count += 1 }
    return count
  }
}
