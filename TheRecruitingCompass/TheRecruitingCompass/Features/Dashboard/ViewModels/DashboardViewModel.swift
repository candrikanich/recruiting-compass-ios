import Foundation
import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
  @Published var isLoggingOut = false
  @Published var logoutErrorMessage: String?

  private let authManager: AuthManager

  var userEmail: String {
    authManager.user?.email ?? "Unknown"
  }

  var truncatedSessionToken: String {
    guard let token = authManager.session?.accessToken else {
      return "No session"
    }
    let truncationLength = min(20, token.count)
    return String(token.prefix(truncationLength)) + "..."
  }

  init(authManager: AuthManager = .shared) {
    self.authManager = authManager
  }

  func logout() async {
    isLoggingOut = true
    logoutErrorMessage = nil
    defer { isLoggingOut = false }

    do {
      try await authManager.logout()
    } catch {
      logoutErrorMessage = "Failed to log out. Please try again."
    }
  }
}
