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

  func logout() async throws {
    self.user = nil
    self.session = nil
    self.isAuthenticated = false
    self.errorMessage = nil
  }

  func restoreSession() async {
    isCheckingSession = true
    defer { isCheckingSession = false }

    do {
      // TODO: Implement session restoration from Keychain
      // For now, assume no existing session
      self.isAuthenticated = false
    } catch {
      self.isAuthenticated = false
    }
  }
}
