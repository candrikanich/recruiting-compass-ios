import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "InviteJoinViewModel"
)

enum InviteJoinState: Equatable {
  case loading
  case loaded(InviteDetails)
  case error(InviteError)
}

@Observable
@MainActor
final class InviteJoinViewModel {
  var state: InviteJoinState = .loading
  var isAccepting = false
  var navigateToDashboard = false
  var errorMessage: String?

  var loginEmail: String = ""
  var loginPassword: String = ""

  private let token: String
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging

  var isAuthenticated: Bool { authManager.isAuthenticated }

  var inviteDetails: InviteDetails? {
    if case .loaded(let d) = state { return d }
    return nil
  }

  init(
    token: String,
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.token = token
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  func loadInvite() async {
    state = .loading
    do {
      let details = try await familyService.lookupInviteByToken(token)
      state = .loaded(details)
    } catch let err as InviteError {
      state = .error(err)
    } catch {
      logger.error("lookupInviteByToken: \(error.localizedDescription)")
      state = .error(.serverError(error.localizedDescription))
    }
  }

  func accept() async {
    errorMessage = nil
    isAccepting = true
    defer { isAccepting = false }

    do {
      if !authManager.isAuthenticated {
        try await authManager.login(email: loginEmail, password: loginPassword)
      }
      try await familyService.acceptInvite(token: token)
      navigateToDashboard = true
    } catch let err as InviteError {
      errorMessage = err.errorDescription
    } catch {
      logger.error("acceptInvite: \(error.localizedDescription)")
      errorMessage = "Failed to connect to family. Please try again."
    }
  }

  nonisolated deinit {}
}
