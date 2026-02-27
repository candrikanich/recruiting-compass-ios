import Observation
import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyManagementViewModel")

@Observable
@MainActor
final class FamilyManagementViewModel {
  // MARK: - Player State
  var familyCode: String?
  var familyId: String?
  var familyName: String?
  var codeGeneratedAt: String?
  var familyMembers: [FamilyMember] = []

  // MARK: - Parent State
  var parentFamilies: [ParentFamilyData] = []
  var codeInput: String = ""

  // MARK: - Shared State
  var isLoading = false
  var loadingMembers = false
  var errorMessage: String?
  var successMessage: String?
  var showSuccessToast = false
  var showDeleteConfirmation = false
  var memberToRemove: FamilyMember?
  var showRegenerateConfirmation = false

  // MARK: - Dependencies
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging

  // MARK: - Computed Properties
  var isPlayer: Bool {
    authManager.user?.role == .player
  }

  var isParent: Bool {
    authManager.user?.role == .parent
  }

  var isCodeInputValid: Bool {
    let trimmed = codeInput.trimmingCharacters(in: .whitespaces)
    return trimmed.range(of: FamilyConstants.Validation.codePattern, options: .regularExpression) != nil
  }

  var formattedCodeGeneratedAt: String? {
    guard let timestamp = codeGeneratedAt else { return nil }
    return DateFormatter.familyCodeDate.string(from: ISO8601DateFormatter().date(from: timestamp) ?? Date())
  }

  // MARK: - Initialization
  init(
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  // MARK: - Load Data
  func loadData() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    if isPlayer {
      await loadPlayerData()
    } else if isParent {
      await loadParentData()
    }
  }

  // MARK: - Player Actions
  private func loadPlayerData() async {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return
    }

    do {
      // Fetch or create family unit
      if let familyUnit = try await familyService.getFamilyUnit(forPlayerUserId: userId) {
        familyCode = familyUnit.familyCode
        familyId = familyUnit.id
        familyName = familyUnit.familyName
        codeGeneratedAt = familyUnit.codeGeneratedAt

        // Load family members
        await loadFamilyMembers(familyUnitId: familyUnit.id)
      } else {
        // No family unit exists, create one
        await createFamily()
      }
    } catch {
      logger.error("Failed to load player data: \(error.localizedDescription)")
      errorMessage = "Failed to load family data. Please try again."
    }
  }

  private func loadFamilyMembers(familyUnitId: String) async {
    loadingMembers = true
    defer { loadingMembers = false }

    do {
      familyMembers = try await familyService.fetchFamilyMembers(familyUnitId: familyUnitId)
    } catch {
      logger.error("Failed to load family members: \(error.localizedDescription)")
      errorMessage = "Failed to load family members"
    }
  }

  func createFamily() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let response = try await familyService.createFamily()
      familyCode = response.familyCode
      familyId = response.familyId
      familyName = response.familyName
      codeGeneratedAt = ISO8601DateFormatter().string(from: Date())
      familyMembers = []

      showSuccess("Family created successfully!")
    } catch let error as FamilyError {
      logger.error("Failed to create family: \(error.localizedDescription)")
      errorMessage = error.errorDescription ?? "Failed to create family. Please try again."
    } catch {
      logger.error("Failed to create family: \(error.localizedDescription)")
      errorMessage = "Failed to create family. Please try again."
    }
  }

  func copyCodeToClipboard() {
    guard let code = familyCode else { return }
    UIPasteboard.general.string = code
    showSuccess("Family code copied to clipboard!")
  }

  func confirmRegenerateCode() {
    showRegenerateConfirmation = true
  }

  func regenerateCode() async {
    guard let familyId = familyId else {
      errorMessage = "No family ID available"
      return
    }

    isLoading = true
    errorMessage = nil
    showRegenerateConfirmation = false
    defer { isLoading = false }

    do {
      let response = try await familyService.regenerateCode(familyId: familyId)
      familyCode = response.familyCode
      codeGeneratedAt = ISO8601DateFormatter().string(from: Date())

      showSuccess("Family code regenerated successfully!")
    } catch {
      logger.error("Failed to regenerate code: \(error.localizedDescription)")
      errorMessage = "Failed to regenerate code. Please try again."
    }
  }

  func confirmRemoveMember(_ member: FamilyMember) {
    memberToRemove = member
    showDeleteConfirmation = true
  }

  func removeMember() async {
    guard let member = memberToRemove else { return }

    isLoading = true
    errorMessage = nil
    showDeleteConfirmation = false
    defer { isLoading = false }

    do {
      try await familyService.removeFamilyMember(memberId: member.id)

      // Remove from local state
      familyMembers.removeAll { $0.id == member.id }
      memberToRemove = nil

      showSuccess("Family member removed successfully!")
    } catch {
      logger.error("Failed to remove member: \(error.localizedDescription)")
      errorMessage = "Failed to remove family member. Please try again."
    }
  }

  // MARK: - Parent Actions
  private func loadParentData() async {
    do {
      parentFamilies = try await familyService.getParentFamilies()
    } catch {
      logger.error("Failed to load parent families: \(error.localizedDescription)")
      errorMessage = "Failed to load families. Please try again."
    }
  }

  func joinFamily() async {
    let code = codeInput.trimmingCharacters(in: .whitespaces).uppercased()

    guard isCodeInputValid else {
      errorMessage = "Invalid family code format. Codes look like FAM-XXXXXX"
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await familyService.joinFamilyWithCode(familyCode: code)

      // Reload parent families
      await loadParentData()

      // Clear input
      codeInput = ""

      showSuccess("Successfully joined family!")
    } catch let error as FamilyError {
      errorMessage = error.errorDescription
    } catch {
      logger.error("Failed to join family: \(error.localizedDescription)")
      errorMessage = "Failed to join family. Please try again."
    }
  }

  // MARK: - Helpers
  private func showSuccess(_ message: String) {
    successMessage = message
    showSuccessToast = true

    Task {
      try? await Task.sleep(nanoseconds: FamilyConstants.Duration.successToast)
      await MainActor.run {
        showSuccessToast = false
        successMessage = nil
      }
    }
  }

  func shareCode() {
    guard let code = familyCode else { return }
    let text = "Join my family on The Recruiting Compass with code: \(code)"

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootVC = window.rootViewController else {
      return
    }

    let activityVC = UIActivityViewController(
      activityItems: [text],
      applicationActivities: nil
    )

    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = window
      popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }

    rootVC.present(activityVC, animated: true)
  }

  func formatCodeInput() {
    codeInput = codeInput.uppercased()
  }

  func clearError() {
    errorMessage = nil
  }
}

