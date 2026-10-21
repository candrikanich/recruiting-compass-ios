import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilySetup")

/// The create-or-join screen the family-required gate shows. Nothing here runs on its own: a family is only
/// created by an explicit tap, and never while the user has a valid pending invitation (they join instead).
@Observable
@MainActor
final class FamilySetupViewModel {
  nonisolated deinit {}

  private(set) var isChecking = true
  private(set) var offersCreate = true
  private(set) var isSubmitting = false
  var familyCode = ""
  var errorMessage: String?

  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging
  private let onMembershipChanged: @MainActor () async -> Void

  var isCodeValid: Bool {
    normalizedCode.range(of: FamilyConstants.Validation.codePattern, options: .regularExpression) != nil
  }

  private var normalizedCode: String { familyCode.trimmingCharacters(in: .whitespaces).uppercased() }

  init(
    familyService: any FamilyManaging,
    authManager: any AuthManaging,
    onMembershipChanged: @escaping @MainActor () async -> Void
  ) {
    self.familyService = familyService
    self.authManager = authManager
    self.onMembershipChanged = onMembershipChanged
  }

  /// A failed lookup falls back to offering create (web parity). Create is still an explicit tap; a server guard
  /// (409, web#1390) is not built yet.
  func checkForPendingInvite() async {
    isChecking = true
    defer { isChecking = false }
    guard let email = authManager.user?.email else { return }
    do {
      let invitations = try await familyService.fetchInvitationsAddressed(toEmail: email)
      offersCreate = FamilyGate.offersCreate(invitations: invitations, email: email, now: .now)
    } catch {
      logger.error("Pending invitation lookup failed: \(error.localizedDescription, privacy: .public)")
      offersCreate = true
    }
  }

  func createFamily() async {
    guard offersCreate else { return }
    guard let role = authManager.user?.role else {
      errorMessage = "We couldn't tell which kind of account this is. Please sign out and back in."
      return
    }
    await submit { [familyService] in _ = try await familyService.createFamily(role: role) }
  }

  func joinWithCode() async {
    guard isCodeValid else {
      errorMessage = "That doesn't look like a family code. Codes look like FAM-ABC123."
      return
    }
    let code = normalizedCode
    await submit { [familyService] in _ = try await familyService.joinFamilyWithCode(familyCode: code) }
  }

  private func submit(_ request: () async throws -> Void) async {
    isSubmitting = true
    errorMessage = nil
    defer { isSubmitting = false }
    do {
      try await request()
      await onMembershipChanged()
    } catch FamilyError.createConflict {
      errorMessage = FamilyError.createConflict.errorDescription
      await onMembershipChanged()
      await checkForPendingInvite()
    } catch {
      logger.error("Family setup request failed: \(error.localizedDescription, privacy: .public)")
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Something went wrong. Please try again."
    }
  }
}
