import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthManager: ObservableObject, AuthManaging {
  static let shared = AuthManager()

  @Published var isAuthenticated = false
  @Published var isCheckingSession = true
  @Published var user: User?
  @Published var session: Session?
  @Published var errorMessage: String?

  private let keychain = KeychainHelper.shared
  private let sessionKey = "savedSession"

  init() {
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
      // Try to load session from Keychain
      let savedSession: Session = try keychain.load(Session.self, forKey: sessionKey)

      // Check if session is expired
      let now = Int(Date().timeIntervalSince1970)
      if savedSession.expiresAt > now {
        // Session is still valid - refresh to get latest user data
        do {
          let updatedUser = try await SupabaseManager.shared.refreshSession()
          // If refresh succeeds, get the new session
          if let newSession = try await SupabaseManager.shared.getCurrentSession() {
            self.session = newSession
            self.user = updatedUser
            self.isAuthenticated = true
            self.errorMessage = nil
            try keychain.save(newSession, forKey: sessionKey)
          } else {
            // No session after refresh, clear everything
            self.session = nil
            self.user = nil
            self.isAuthenticated = false
            try keychain.delete(forKey: sessionKey)
          }
        } catch {
          // Refresh failed, but session is still valid - use cached data
          self.session = savedSession
          self.user = savedSession.user
          self.isAuthenticated = true
        }
      } else {
        // Session expired, try to refresh
        do {
          let updatedUser = try await SupabaseManager.shared.refreshSession()
          if let newSession = try await SupabaseManager.shared.getCurrentSession() {
            self.session = newSession
            self.user = updatedUser
            self.isAuthenticated = true
            self.errorMessage = nil
            try keychain.save(newSession, forKey: sessionKey)
          } else {
            self.session = nil
            self.user = nil
            self.isAuthenticated = false
            try keychain.delete(forKey: sessionKey)
          }
        } catch {
          // Refresh failed, clear stored session
          self.session = nil
          self.user = nil
          self.isAuthenticated = false
          try? keychain.delete(forKey: sessionKey)
        }
      }
    } catch {
      // No saved session found
      self.isAuthenticated = false
      self.session = nil
      self.user = nil
    }
  }
}
