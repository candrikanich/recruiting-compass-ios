import Combine
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "InteractionDetailViewModel"
)

@MainActor
final class InteractionDetailViewModel: ObservableObject {

  // MARK: - Published State

  @Published var interaction: Interaction?
  @Published var school: School?
  @Published var coach: Coach?
  @Published var loggedByName: String = "Unknown"
  @Published var isLoading = false
  @Published var errorMessage: String?

  // Delete state
  @Published var showDeleteConfirmation = false
  @Published var isDeleting = false

  // MARK: - Dependencies

  private let interactionId: String
  private let interactionsService: InteractionsManaging
  private let authManager: AuthManaging
  private let familyUnitId: String

  // MARK: - Init

  init(
    interactionId: String,
    familyUnitId: String,
    interactionsService: InteractionsManaging,
    authManager: AuthManaging
  ) {
    self.interactionId = interactionId
    self.familyUnitId = familyUnitId
    self.interactionsService = interactionsService
    self.authManager = authManager
  }

  // MARK: - Computed Properties

  var isOwner: Bool {
    interaction?.loggedBy == authManager.user?.id
  }

  var canDelete: Bool {
    // Only owner can delete (role check removed - spec says only players can create, so only they can delete)
    isOwner
  }

  var canExport: Bool {
    interaction != nil
  }

  var formattedDate: String {
    guard let interaction = interaction else { return "Unknown" }
    let date = interaction.displayDate
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  var loggedByDisplay: String {
    if interaction?.loggedBy == authManager.user?.id {
      return "You"
    }
    return loggedByName
  }

  var displaySubject: String {
    interaction?.displaySubject ?? "Interaction"
  }

  var hasContent: Bool {
    !(interaction?.content?.isEmpty ?? true)
  }

  var hasAttachments: Bool {
    interaction?.hasAttachments ?? false
  }

  // MARK: - Loading

  func loadInteraction() async {
    guard !isLoading else {
      logger.debug("Already loading, skipping duplicate request")
      return
    }

    logger.debug("Loading interaction: \(self.interactionId)")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // Fetch interaction
      interaction = try await interactionsService.fetchInteraction(id: interactionId)
      logger.info("Loaded interaction: \(self.interactionId)")

      // Load related data
      await loadRelatedData()
    } catch {
      logger.error("Failed to load interaction: \(error.localizedDescription)")
      errorMessage = "Failed to load interaction. It may have been deleted."
    }
  }

  private func loadRelatedData() async {
    guard let interaction = interaction else { return }

    // Load school
    if let schoolId = interaction.schoolId {
      do {
        let schools = try await interactionsService.fetchSchools(familyUnitId: familyUnitId)
        school = schools.first { $0.id == schoolId }
        if school == nil {
          logger.warning("School not found: \(schoolId)")
        }
      } catch {
        logger.error("Failed to load school: \(error.localizedDescription)")
      }
    }

    // Load coach
    if let coachId = interaction.coachId {
      do {
        let coaches = try await interactionsService.fetchCoaches(familyUnitId: familyUnitId)
        coach = coaches.first { $0.id == coachId }
        if coach == nil {
          logger.warning("Coach not found: \(coachId)")
        }
      } catch {
        logger.error("Failed to load coach: \(error.localizedDescription)")
      }
    }

    // Load logged-by user name
    if let loggedBy = interaction.loggedBy {
      do {
        loggedByName = try await interactionsService.fetchLoggedByUserName(userId: loggedBy)
      } catch {
        logger.error("Failed to load user name: \(error.localizedDescription)")
        loggedByName = "Unknown"
      }
    }
  }

  // MARK: - Export

  func exportInteraction() -> String {
    guard let interaction = interaction else { return "" }

    let lines: [(String, String)] = [
      ("Subject", interaction.displaySubject),
      ("Type", interaction.type.displayName),
      ("Direction", interaction.direction.displayName),
      ("Sentiment", interaction.sentiment?.displayName ?? "N/A"),
      ("School", school?.name ?? "N/A"),
      ("Coach", coach.map { "\($0.firstName) \($0.lastName)" } ?? "N/A"),
      ("Date", formattedDate),
      ("Content", interaction.content ?? "N/A"),
      ("Attachments", "\(interaction.attachmentCount)")
    ]

    // CSV format
    let header = "Field,Value"
    let rows = lines.map { "\"\($0.0)\",\"\($0.1)\"" }
    return ([header] + rows).joined(separator: "\n")
  }

  // MARK: - Delete

  func deleteInteraction() async -> Bool {
    guard let interaction = interaction else {
      logger.warning("No interaction to delete")
      return false
    }

    guard canDelete else {
      logger.warning("User cannot delete this interaction")
      errorMessage = "You don't have permission to delete this interaction"
      return false
    }

    logger.debug("Deleting interaction: \(interaction.id)")
    isDeleting = true
    errorMessage = nil
    defer { isDeleting = false }

    do {
      // Try simple delete first
      try await interactionsService.deleteInteraction(id: interaction.id)
      logger.info("Deleted interaction: \(interaction.id)")
      return true
    } catch {
      let message = error.localizedDescription

      // Check for FK constraint error → try cascade
      if message.contains("Cannot delete") ||
         message.contains("violates foreign key constraint") ||
         message.contains("still referenced") {

        logger.debug("Simple delete failed, trying cascade delete")

        do {
          let result = try await interactionsService.cascadeDeleteInteraction(id: interaction.id)
          logger.info("Cascade deleted interaction: \(interaction.id), notes: \(result.deletedNotes)")
          return true
        } catch {
          logger.error("Cascade delete failed: \(error.localizedDescription)")
          errorMessage = "Failed to delete interaction. Please try again."
          return false
        }
      } else {
        logger.error("Delete failed: \(error.localizedDescription)")
        errorMessage = "Failed to delete interaction. Please try again."
        return false
      }
    }
  }

  func confirmDelete() {
    showDeleteConfirmation = true
  }

  func cancelDelete() {
    showDeleteConfirmation = false
  }
}
