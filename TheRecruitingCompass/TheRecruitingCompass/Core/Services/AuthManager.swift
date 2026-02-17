import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class AuthManager: AuthManaging {
  static let shared = AuthManager()

  var isAuthenticated = false
  var isCheckingSession = true
  var user: User?
  var session: Session?
  var errorMessage: String?

  private let keychain = KeychainHelper.shared
  private let sessionKey = "savedSession"

  init() {
    // Unstructured Task is intentional: @Observable classes cannot have async init.
    // @MainActor ensures session restoration runs on the main thread.
    Task {
      await restoreSession()
    }
  }

  func login(email: String, password: String) async throws {
    do {
      let (user, session) = try await SupabaseManager.shared.signIn(email: email, password: password)
      self.user = user
      self.session = session
      self.isAuthenticated = true
      self.errorMessage = nil

      // Save session to Keychain
      try keychain.save(session, forKey: sessionKey)
    } catch {
      self.isAuthenticated = false
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func signup(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws {
    do {
      let (user, session) = try await SupabaseManager.shared.signUp(
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
      if let session = session {
        try keychain.save(session, forKey: sessionKey)
      }
    } catch {
      self.isAuthenticated = false
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func refreshSession() async throws -> User {
    do {
      let updatedUser = try await SupabaseManager.shared.refreshSession()
      self.user = updatedUser
      return updatedUser
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func resendVerificationEmail(email: String) async throws {
    do {
      try await SupabaseManager.shared.resendVerificationEmail(email: email)
      self.errorMessage = nil
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func resetPasswordForEmail(email: String) async throws {
    do {
      try await SupabaseManager.shared.resetPasswordForEmail(email: email)
      self.errorMessage = nil
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func updatePassword(newPassword: String) async throws {
    do {
      try await SupabaseManager.shared.updatePassword(newPassword: newPassword)
      self.errorMessage = nil
    } catch {
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      throw error
    }
  }

  func logout() async throws {
    do {
      try await SupabaseManager.shared.signOut()
    } catch {
      // Log the error but continue with local cleanup
      self.errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
    }

    self.user = nil
    self.session = nil
    self.isAuthenticated = false
    self.errorMessage = nil

    // Clear session from Keychain
    try? keychain.delete(forKey: sessionKey)
  }

  func restoreSession() async {
    isCheckingSession = true
    defer { isCheckingSession = false }

    do {
      let savedSession: Session = try keychain.load(Session.self, forKey: sessionKey)
      let now = Int(Date().timeIntervalSince1970)

      if savedSession.expiresAt > now {
        // Session still valid — refresh to get latest user data, fall back to cached on failure
        await refreshAndSaveSession(fallback: savedSession)
      } else {
        // Session expired — must successfully refresh or clear all state
        await refreshAndSaveSession(fallback: nil)
      }
    } catch {
      // No saved session found
      clearSession()
    }
  }

  /// Attempts to refresh the Supabase session and persist the result to Keychain.
  /// - Parameter fallback: If provided and refresh fails, uses this cached session instead of clearing state.
  private func refreshAndSaveSession(fallback: Session?) async {
    do {
      let updatedUser = try await SupabaseManager.shared.refreshSession()
      if let newSession = try await SupabaseManager.shared.getCurrentSession() {
        self.session = newSession
        self.user = updatedUser
        self.isAuthenticated = true
        self.errorMessage = nil
        try keychain.save(newSession, forKey: sessionKey)
      } else {
        clearSession()
        try keychain.delete(forKey: sessionKey)
      }
    } catch {
      if let fallback {
        // Refresh failed but cached session is still valid — use it
        self.session = fallback
        self.user = fallback.user
        self.isAuthenticated = true
      } else {
        clearSession()
        try? keychain.delete(forKey: sessionKey)
      }
    }
  }

  private func clearSession() {
    self.session = nil
    self.user = nil
    self.isAuthenticated = false
  }
}
