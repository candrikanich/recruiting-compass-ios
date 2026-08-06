import Foundation
import OSLog
import SwiftUI
import Observation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AuthManager")

@Observable
@MainActor
final class AuthManager: AuthManaging {
  nonisolated deinit {}
  static let shared = AuthManager()

  var isAuthenticated = false
  var isCheckingSession = true
  var user: User?
  var session: Session?
  var errorMessage: String?
  var pendingBiometricEnrollmentOffer: Bool = false

  private let keychain = KeychainHelper.shared
  private let sessionKey = "savedSession"
  private let supabaseManager: any SupabaseManaging
  private let biometricEnabledKey = "biometricEnabled"
  private let biometricService: any BiometricServiceProtocol

  var biometricEnabled: Bool {
    (try? keychain.load(Bool.self, forKey: biometricEnabledKey)) ?? false
  }

  init(supabaseManager: (any SupabaseManaging)? = nil, biometricService: (any BiometricServiceProtocol)? = nil) {
    self.supabaseManager = supabaseManager ?? SupabaseManager.shared
    self.biometricService = biometricService ?? BiometricService()
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
      // Clear persisted session so UI tests always start from the landing screen.
      // Debug-only: a Release binary must never honor this session-wiping flag.
      try? KeychainHelper.shared.delete(forKey: "savedSession")
      isCheckingSession = false
      return
    }
    #endif
    // Unstructured Task is intentional: @Observable classes cannot have async init.
    // @MainActor ensures session restoration runs on the main thread.
    Task {
      await restoreSession()
    }
  }

  func login(email: String, password: String) async throws {
    logger.debug("Attempting login for: \(email.prefix(3))***")
    do {
      let (user, session) = try await supabaseManager.signIn(email: email, password: password)
      self.user = user
      self.session = session
      self.isAuthenticated = true
      self.errorMessage = nil

      // Save session to Keychain
      try keychain.save(session, forKey: sessionKey)
      logger.info("Login successful for user: \(user.id, privacy: .private)")
    } catch {
      self.isAuthenticated = false
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Login failed: \(error.localizedDescription)")
      throw error
    }
  }

  func signup(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String? = nil
  ) async throws {
    logger.debug("Attempting signup for: \(email.prefix(3))*** role: \(role.rawValue)")
    if let dob = dateOfBirth, COPPAHelper.isUnderAge(dob) {
      logger.info("Signup blocked: COPPA age restriction")
      throw AuthError.coppaUnderAge
    }
    do {
      let (user, session) = try await supabaseManager.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: familyCode
      )
      self.user = user
      self.session = session
      self.isAuthenticated = session != nil
      self.errorMessage = nil

      // Save session to Keychain if signup returned a session
      if let session {
        try keychain.save(session, forKey: sessionKey)
      }
      logger.info("Signup successful for user: \(user.id, privacy: .private), session: \(session != nil)")
    } catch {
      self.isAuthenticated = false
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Signup failed: \(error.localizedDescription)")
      throw error
    }
  }

  func refreshSession() async throws -> User {
    logger.debug("Refreshing session")
    do {
      _ = try await supabaseManager.refreshSession()
      guard let newSession = try await supabaseManager.getCurrentSession() else {
        throw AuthError.serverError("No session after refresh")
      }
      self.session = newSession
      self.user = newSession.user
      try keychain.save(newSession, forKey: sessionKey)
      logger.info("Session refreshed for user: \(newSession.user.id, privacy: .private)")
      return newSession.user
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Session refresh failed: \(error.localizedDescription)")
      throw error
    }
  }

  func resendVerificationEmail(email: String) async throws {
    logger.debug("Resending verification email to: \(email.prefix(3))***")
    do {
      try await supabaseManager.resendVerificationEmail(email: email)
      self.errorMessage = nil
      logger.info("Verification email sent")
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Resend verification failed: \(error.localizedDescription)")
      throw error
    }
  }

  func resetPasswordForEmail(email: String) async throws {
    logger.debug("Requesting password reset for: \(email.prefix(3))***")
    do {
      try await supabaseManager.resetPasswordForEmail(email: email)
      self.errorMessage = nil
      logger.info("Password reset email sent")
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Password reset request failed: \(error.localizedDescription)")
      throw error
    }
  }

  func updatePassword(newPassword: String) async throws {
    logger.debug("Updating password")
    do {
      try await supabaseManager.updatePassword(newPassword: newPassword)
      self.errorMessage = nil
      logger.info("Password updated successfully")
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? "An unexpected error occurred. Please try again."
      logger.error("Password update failed: \(error.localizedDescription)")
      throw error
    }
  }

  func updateUser(_ user: User) {
    self.user = user
    if var session = session {
      session = Session(
        accessToken: session.accessToken,
        tokenType: session.tokenType,
        expiresIn: session.expiresIn,
        expiresAt: session.expiresAt,
        refreshToken: session.refreshToken,
        user: user
      )
      self.session = session
      do {
        try keychain.save(session, forKey: sessionKey)
      } catch {
        // Session stays valid in memory; the next launch will require re-login.
        logger.error("Failed to persist session to Keychain: \(error.localizedDescription)")
      }
    }
  }

  func enableBiometrics() throws {
    try keychain.save(true, forKey: biometricEnabledKey)
  }

  func disableBiometrics() {
    try? keychain.delete(forKey: biometricEnabledKey)
  }

  func authenticateWithBiometrics() async throws {
    try await biometricService.authenticate(reason: "Sign in to The Recruiting Compass")
  }

  func logout() async throws {
    // Delete device token before clearing user identity
    await PushNotificationManager.shared.deleteDeviceToken()
    do {
      try await supabaseManager.signOut()
    } catch {
      // Ignore sign-out errors and continue with local cleanup
      logger.warning("Sign-out from Supabase failed, local session will be cleared: \(error.localizedDescription)")
    }

    self.user = nil
    self.session = nil
    self.isAuthenticated = false
    self.errorMessage = nil

    // Clear session from Keychain
    try? keychain.delete(forKey: sessionKey)
    disableBiometrics()
  }

  func restoreSession() async {
    logger.debug("Restoring session from Keychain")
    isCheckingSession = true
    defer { isCheckingSession = false }

    do {
      let savedSession: Session = try keychain.load(Session.self, forKey: sessionKey)
      let now = Int(Date.now.timeIntervalSince1970)

      if savedSession.expiresAt > now {
        logger.debug("Cached session valid, refreshing to get latest user data")
        await refreshAndSaveSession(fallback: savedSession)
      } else {
        logger.debug("Cached session expired, attempting refresh")
        await refreshAndSaveSession(fallback: nil)
      }
    } catch {
      logger.info("No saved session found, user must log in")
      clearSession()
    }
  }

  /// Attempts to refresh the Supabase session and persist the result to Keychain.
  /// - Parameter fallback: If provided and refresh fails, uses this cached session instead of clearing state.
  private func refreshAndSaveSession(fallback: Session?) async {
    // Capture Sendable references before hopping off the main actor
    let savedSession = try? keychain.load(Session.self, forKey: sessionKey)
    let mgr = supabaseManager
    let log = logger

    // Run all Supabase network calls off the main actor so a slow/timed-out
    // refresh (can take up to ~157s on iOS) doesn't block UI input.
    typealias RefreshResult = (user: User, session: Session?)
    let result = await Task.detached {
      if let saved = savedSession {
        do {
          try await mgr.setSession(accessToken: saved.accessToken, refreshToken: saved.refreshToken)
        } catch {
          log.error("Failed to set saved session: \(error.localizedDescription)")
        }
      }
      let updatedUser = try await mgr.refreshSession()
      let newSession = try await mgr.getCurrentSession()
      return RefreshResult(user: updatedUser, session: newSession)
    }.result

    switch result {
    case .success(let (updatedUser, newSession)):
      if let newSession {
        self.session = newSession
        self.user = updatedUser
        self.isAuthenticated = true
        self.errorMessage = nil
        try? keychain.save(newSession, forKey: sessionKey)
        logger.info("Session refreshed and saved for user: \(updatedUser.id, privacy: .private)")
      } else {
        logger.warning("No session returned after refresh, clearing state")
        clearSession()
        try? keychain.delete(forKey: sessionKey)
      }
    case .failure(let error):
      if let authError = error as? AuthError, case .sessionInvalid = authError {
        // Auth user was deleted (e.g. from Supabase); don't use stale fallback
        logger.warning("Session invalid (user may have been deleted), clearing state")
        clearSession()
        try? keychain.delete(forKey: sessionKey)
        return
      }
      if let fallback {
        // Refresh failed but cached session is still valid — use it
        logger.warning("Session refresh failed, using cached session: \(error.localizedDescription)")
        self.session = fallback
        self.user = fallback.user
        self.isAuthenticated = true
      } else {
        logger.error("Session refresh failed, clearing state: \(error.localizedDescription)")
        clearSession()
        try? keychain.delete(forKey: sessionKey)
      }
    }
  }

  private func clearSession() {
    self.session = nil
    self.user = nil
    self.isAuthenticated = false
    self.errorMessage = nil
  }
}
