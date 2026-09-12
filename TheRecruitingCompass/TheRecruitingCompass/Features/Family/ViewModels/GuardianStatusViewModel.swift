import Foundation
import OSLog
import Observation

private let guardianLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "GuardianStatus"
)

/// Guardian-confirmation state for the signed-in player.
///
/// `isLocked` is the single switch every gated surface reads, so the capability matrix in
/// `planning/2026-09-11-guardian-linked-signup-spec.md` lives in one place rather than
/// being re-derived per view. Parity with web's `useGuardianStatus`.
@Observable
@MainActor
final class GuardianStatusViewModel {
  nonisolated deinit {}

  private(set) var status: GuardianStatus?
  private(set) var hasLoaded = false
  var isSending = false
  var errorMessage: String?

  private let service: any GuardianClaimServicing
  private let authManager: any AuthManaging

  init(
    service: (any GuardianClaimServicing)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.service = service ?? GuardianClaimServiceImpl()
    self.authManager = authManager ?? AuthManager.shared
  }

  /// True while an unconfirmed guardian claim is outstanding.
  var isPending: Bool { status?.pending == true }

  /// True when outbound features must be disabled. Identical to `isPending` today; kept
  /// distinct so the lock can diverge from the banner later (e.g. the 21-day freeze,
  /// which restricts more than the pending state does) without touching every call site.
  var isLocked: Bool { isPending }

  var guardianEmailMasked: String? { status?.guardianEmailMasked }

  func load(force: Bool = false) async {
    guard service.isConfigured else { return }
    guard !hasLoaded || force else { return }
    do {
      status = try await service.status(accessToken: authManager.session?.accessToken)
    } catch {
      // Fail open: a status lookup that errors must not lock an adult out of their own
      // account. The server endpoints and the DB gate remain authoritative regardless.
      status = nil
      guardianLogger.error("Guardian status load failed: \(error.localizedDescription)")
    }
    hasLoaded = true
  }

  /// Resend the confirmation email, optionally to a different guardian address.
  /// - Returns: true when the email was sent.
  @discardableResult
  func resend(guardianEmail: String? = nil) async -> Bool {
    guard !isSending else { return false }
    isSending = true
    errorMessage = nil
    defer { isSending = false }

    do {
      try await service.resend(
        guardianEmail: guardianEmail,
        accessToken: authManager.session?.accessToken
      )
      await load(force: true)
      return true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription
        ?? "Couldn't send that email. Please try again."
      guardianLogger.error("Guardian resend failed: \(error.localizedDescription)")
      return false
    }
  }
}
