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
      guard let accessToken = authManager.session?.accessToken else {
        errorMessage = "Please sign in to confirm."
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
