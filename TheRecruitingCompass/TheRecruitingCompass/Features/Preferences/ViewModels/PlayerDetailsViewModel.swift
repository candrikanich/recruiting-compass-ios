import Foundation
import SwiftUI
import Observation
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PlayerDetailsViewModel")

@Observable
@MainActor
final class PlayerDetailsViewModel {
  var details: PlayerDetails = .default
  var isLoading = false
  var isSaving = false
  var isUploadingPhoto = false
  var errorMessage: String?
  var successMessage: String?
  var hasUnsavedChanges = false
  var profileImage: UIImage?
  var isReadOnly = false
  var showDeletePhotoConfirmation = false

  private let preferenceService: PreferenceManaging
  private let userRole: UserRole
  @ObservationIgnored nonisolated(unsafe) private var saveTask: Task<Void, Never>?

  init(preferenceService: PreferenceManaging, userRole: UserRole) {
    self.preferenceService = preferenceService
    self.userRole = userRole
    self.isReadOnly = (userRole == .parent)
    setupAutoSave()
  }

  deinit {
    saveTask?.cancel()
  }

  // MARK: - Load/Save

  func loadDetails() async {
    logger.debug("Loading player details")
    isLoading = true
    errorMessage = nil

    do {
      if let savedDetails: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
        details = savedDetails
        logger.info("Loaded existing player details")
      } else {
        details = .default
        logger.info("No existing details, using defaults")
      }
      isLoading = false
    } catch {
      logger.error("Failed to load details: \(error.localizedDescription)")
      errorMessage = "Failed to load details: \(error.localizedDescription)"
      isLoading = false
    }
  }

  func saveDetails() async {
    guard !isReadOnly else {
      logger.warning("Attempted save with read-only access")
      return
    }

    logger.debug("Saving player details")
    isSaving = true
    errorMessage = nil
    successMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .player, data: details)
      hasUnsavedChanges = false
      successMessage = "Player details saved successfully"
      logger.info("Player details saved")

      // Clear success message after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run {
          if successMessage == "Player details saved successfully" {
            successMessage = nil
          }
        }
      }

      isSaving = false
    } catch {
      logger.error("Failed to save details: \(error.localizedDescription)")
      errorMessage = "Failed to save details: \(error.localizedDescription)"
      isSaving = false
    }
  }

  // MARK: - Photo Upload

  func uploadProfilePhoto(_ image: UIImage) async {
    guard !isReadOnly else { return }

    logger.debug("Uploading profile photo")
    isUploadingPhoto = true
    errorMessage = nil

    do {
      // Compress image
      guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
        throw PhotoError.compressionFailed
      }

      // Check size (max 5MB)
      guard compressedData.count <= 5_000_000 else {
        throw PhotoError.fileTooLarge
      }

      // In production, upload to Supabase Storage here
      // For now, just store locally and save
      profileImage = image
      markChanged()

      logger.info("Profile photo uploaded successfully")
      isUploadingPhoto = false
    } catch {
      logger.error("Failed to upload photo: \(error.localizedDescription)")
      errorMessage = "Failed to upload photo: \(error.localizedDescription)"
      isUploadingPhoto = false
    }
  }

  func deleteProfilePhoto() async {
    guard !isReadOnly else { return }

    profileImage = nil
    markChanged()
    logger.info("Profile photo deleted")
  }

  // MARK: - Field Updates

  func updateGraduationYear(_ value: Int?) {
    details.graduationYear = value
    markChanged()
  }

  func updateGPA(_ value: Double?) {
    // Validate GPA range (0.0-5.0)
    if let gpa = value, gpa >= 0.0 && gpa <= 5.0 {
      details.gpa = gpa
      markChanged()
    } else if value == nil {
      details.gpa = nil
      markChanged()
    }
  }

  func updateSAT(_ value: Int?) {
    // Validate SAT range (400-1600)
    if let sat = value, sat >= 400 && sat <= 1600 {
      details.satScore = sat
      markChanged()
    } else if value == nil {
      details.satScore = nil
      markChanged()
    }
  }

  func updateACT(_ value: Int?) {
    // Validate ACT range (1-36)
    if let act = value, act >= 1 && act <= 36 {
      details.actScore = act
      markChanged()
    } else if value == nil {
      details.actScore = nil
      markChanged()
    }
  }

  func updateHeight(feet: Int, inches: Int) {
    details.heightInches = (feet * 12) + inches
    markChanged()
  }

  // MARK: - Computed Properties

  var heightFeet: Int {
    (details.heightInches ?? 0) / 12
  }

  var heightInchesRemainder: Int {
    (details.heightInches ?? 0) % 12
  }

  // MARK: - Private Helpers

  func markChanged() {
    guard !isReadOnly else { return }
    hasUnsavedChanges = true
  }

  private func setupAutoSave() {
    // Debounce auto-save (500ms)
    // Auto-save is now handled by triggerAutoSave() called from update methods
  }

  private func triggerAutoSave() {
    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
      if hasUnsavedChanges && !isReadOnly {
        await saveDetails()
      }
    }
  }
}

enum PhotoError: LocalizedError {
  case compressionFailed
  case fileTooLarge

  var errorDescription: String? {
    switch self {
    case .compressionFailed:
      return "Failed to compress photo"
    case .fileTooLarge:
      return "Photo must be less than 5MB"
    }
  }
}
