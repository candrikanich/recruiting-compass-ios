import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "GuardianClaimViewModel"
)

enum GuardianClaimState: Equatable {
  case loading
  case loaded(GuardianClaimDetails)
  case error(String)
  case confirmed
}

/// Drives the guardian-facing confirmation screen reached via a
/// `/guardian/claim/:token` link. Mirrors web's
/// `pages/guardian/claim/[token].vue` and structurally follows
/// `InviteJoinViewModel` (resolve token → sign in if needed → confirm).
@Observable
@MainActor
final class GuardianClaimViewModel {
  nonisolated deinit {}

  var state: GuardianClaimState = .loading
  var isConfirming = false
  var loginEmail = ""
  var loginPassword = ""
  var errorMessage: String?

  private let token: String
  private let guardianService: any GuardianManaging
  private let authManager: any AuthManaging
  private let turnstileTokenProvider: any TurnstileTokenProviding

  var isAuthenticated: Bool { authManager.isAuthenticated }

  var claimDetails: GuardianClaimDetails? {
    if case .loaded(let details) = state { return details }
    return nil
  }

  /// True when a session is authenticated AND it's the guardian this claim names — not the
  /// player, not another guardian. Without this check, `confirm()` would silently send a
  /// non-matching session's token to an endpoint the server rejects, with no path in this
  /// sheet to sign out and switch accounts.
  var isAuthenticatedAsGuardian: Bool {
    guard let details = claimDetails, let email = authManager.user?.email else { return false }
    return email.trimmingCharacters(in: .whitespaces).lowercased()
      == details.guardianEmail.trimmingCharacters(in: .whitespaces).lowercased()
  }

  func signOutToSwitchAccount() async {
    try? await authManager.logout()
  }

  init(
    token: String,
    guardianService: (any GuardianManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil
  ) {
    self.token = token
    self.guardianService = guardianService ?? GuardianServiceImpl()
    self.authManager = authManager ?? AuthManager.shared
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
  }

  func load() async {
    state = .loading
    do {
      let details = try await guardianService.resolveClaim(token: token)
      state = .loaded(details)
      loginEmail = details.guardianEmail
    } catch {
      logger.error("resolveClaim failed: \(error.localizedDescription)")
      state = .error((error as? GuardianServiceError)?.errorDescription ?? "Could not load this confirmation link.")
    }
  }

  func confirm() async {
    errorMessage = nil
    isConfirming = true
    defer { isConfirming = false }

    do {
      if !authManager.isAuthenticated {
        let captchaToken = try await turnstileTokenProvider.getToken()
        try await authManager.login(email: loginEmail, password: loginPassword, captchaToken: captchaToken)
      }
      guard isAuthenticatedAsGuardian, let accessToken = authManager.session?.accessToken else {
        errorMessage = "Please sign in with the guardian email this claim was sent to."
        return
      }
      _ = try await guardianService.acceptClaim(token: token, accessToken: accessToken)
      state = .confirmed
    } catch {
      logger.error("acceptClaim failed: \(error.localizedDescription)")
      errorMessage = (error as? AuthError)?.errorDescription
        ?? (error as? GuardianServiceError)?.errorDescription
        ?? "Could not confirm this account. Please try again."
    }
  }
}
