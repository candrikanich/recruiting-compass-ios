import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthManager: ObservableObject {
  static let shared = AuthManager()

  @Published var isAuthenticated = false
  @Published var user: User?
  @Published var session: Session?
  @Published var errorMessage: String?

  init() {}

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
}
