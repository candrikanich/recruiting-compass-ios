import Combine
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolDetailViewModel")

@MainActor
final class SchoolDetailViewModel: ObservableObject {
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  // Status management
  @Published var statusHistory: [SchoolStatusHistory] = []
  @Published var isUpdatingStatus = false

  // Dependencies
  private let schoolId: String
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  nonisolated init(
    schoolId: String,
    schoolsService: any SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared,
    familyManager: FamilyManager = .shared
  ) {
    self.schoolId = schoolId
    self.schoolsService = schoolsService
    self.authManager = authManager
    self.familyManager = familyManager
  }

  // MARK: - Computed Properties

  var currentUserId: String {
    authManager.user?.id ?? ""
  }

  var privateNoteForCurrentUser: String {
    guard !currentUserId.isEmpty else { return "" }
    return school?.privateNote(for: currentUserId) ?? ""
  }

  // MARK: - Loading

  func loadSchool() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      logger.warning("Cannot load school: no active family")
      return
    }

    do {
      async let schoolData = schoolsService.fetchSchool(id: schoolId, familyUnitId: familyId)
      async let historyData = schoolsService.fetchStatusHistory(schoolId: schoolId)

      school = try await schoolData
      statusHistory = try await historyData

      logger.info("Loaded school: \(self.school?.name ?? "unknown")")
    } catch {
      errorMessage = "Failed to load school: \(error.localizedDescription)"
      logger.error("Failed to load school: \(error.localizedDescription)")
    }
  }

  // MARK: - Status Update

  func updateStatus(to newStatus: SchoolStatus) async {
    guard let school, !currentUserId.isEmpty else { return }

    let previousStatus = SchoolStatus(rawValue: school.status) ?? .interested
    guard newStatus != previousStatus else { return }

    isUpdatingStatus = true
    defer { isUpdatingStatus = false }

    do {
      let updated = try await schoolsService.updateStatus(
        id: schoolId,
        newStatus: newStatus,
        previousStatus: previousStatus,
        userId: currentUserId
      )
      self.school = updated

      // Refresh history
      statusHistory = try await schoolsService.fetchStatusHistory(schoolId: schoolId)
      logger.info("Status updated to \(newStatus.displayName)")
    } catch {
      errorMessage = "Failed to update status"
      logger.error("Failed to update status: \(error.localizedDescription)")
    }
  }

  // MARK: - Favorite Toggle (for Phase 2, placeholder)

  func toggleFavorite() async {
    guard let school else { return }

    let newValue = !school.isFavorite

    // Optimistic update
    self.school = school.with(isFavorite: newValue)

    do {
      try await schoolsService.toggleFavorite(id: schoolId, isFavorite: newValue)
      logger.info("Favorite toggled to \(newValue)")
    } catch {
      // Revert on error
      self.school = school.with(isFavorite: !newValue)
      errorMessage = "Failed to update favorite"
      logger.error("Failed to toggle favorite: \(error.localizedDescription)")
    }
  }
}
