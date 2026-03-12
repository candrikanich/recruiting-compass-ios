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
  case declined
}

@Observable
@MainActor
final class InviteJoinViewModel {
  var state: InviteJoinState = .loading
  var isAccepting = false
  var isDeclining = false
  var navigateToDashboard = false
  var errorMessage: String?

  var showSuccessToast = false
  var successMessage: String?

  var loginEmail: String = ""
  var loginPassword: String = ""

  var signupFirstName: String = ""
  var signupLastName: String = ""
  var signupDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
  var signupPassword: String = ""
  var signupConfirmPassword: String = ""
  var signupAgreeToTerms = false
  var signupError: String?

  private let token: String
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging
  private let preferenceService: any PreferenceManaging

  var isAuthenticated: Bool { authManager.isAuthenticated }

  var inviteDetails: InviteDetails? {
    if case .loaded(let d) = state { return d }
    return nil
  }

  init(
    token: String,
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil
  ) {
    self.token = token
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
  }

  func loadInvite() async {
    state = .loading
    do {
      let details = try await familyService.lookupInviteByToken(token)
      state = .loaded(details)
      loginEmail = details.email
      if let prefill = details.prefill {
        signupFirstName = prefill.firstName
        signupLastName = prefill.lastName
      }
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
      successMessage = "You're connected!"
      if inviteDetails?.emailMismatch == true {
        successMessage = "You're connected! (You used a different email than the invite.)"
      }
      showSuccessToast = true
      try? await Task.sleep(for: .milliseconds(1500))
      navigateToDashboard = true
    } catch let err as InviteError {
      errorMessage = err.errorDescription
    } catch {
      logger.error("acceptInvite: \(error.localizedDescription)")
      errorMessage = "Failed to connect to family. Please try again."
    }
  }

  func signupAndConnect() async {
    guard let invite = inviteDetails else { return }
    signupError = nil

    let first = signupFirstName.trimmingCharacters(in: .whitespaces)
    let last = signupLastName.trimmingCharacters(in: .whitespaces)
    if first.isEmpty || last.isEmpty {
      signupError = "Please enter your first and last name"
      return
    }

    let role = UserRole(rawValue: invite.role) ?? .player
    let dobFormatter = DateFormatter()
    dobFormatter.dateFormat = "yyyy-MM-dd"
    let dobString = dobFormatter.string(from: signupDateOfBirth)

    if role == .player && COPPAHelper.isUnderAge(dobString) {
      signupError = "Players must be 13 or older"
      return
    }

    if signupPassword != signupConfirmPassword {
      signupError = "Passwords don't match"
      return
    }
    if signupPassword.count < 8 {
      signupError = "Password must be at least 8 characters"
      return
    }
    if !signupAgreeToTerms {
      signupError = "Please agree to the Terms and Privacy Policy"
      return
    }

    isAccepting = true
    defer { isAccepting = false }

    do {
      let fullName = "\(first) \(last)"
      try await authManager.signup(
        email: invite.email,
        password: signupPassword,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil
      )
      try await familyService.acceptInvite(token: token)
      await savePrefillPreferences(from: invite.prefill)
      successMessage = "You're connected!"
      if inviteDetails?.emailMismatch == true {
        successMessage = "You're connected! (You used a different email than the invite.)"
      }
      showSuccessToast = true
      try? await Task.sleep(for: .milliseconds(1500))
      navigateToDashboard = true
    } catch {
      logger.error("signupAndConnect: \(error.localizedDescription)")
      signupError = (error as? AuthError)?.errorDescription ?? "Could not create account. Please try again."
    }
  }

  private func savePrefillPreferences(from prefill: InvitePrefill?) async {
    guard let prefill,
          prefill.sport != nil || prefill.position != nil || prefill.graduationYear != nil else { return }
    var details = PlayerDetails.default
    details.primarySport = prefill.sport
    details.primaryPosition = prefill.position
    details.graduationYear = prefill.graduationYear
    _ = try? await preferenceService.savePreferences(category: .player, data: details)
    logger.debug("Saved prefill player preferences from invite")
  }

  func decline() async {
    isDeclining = true
    defer { isDeclining = false }
    do {
      try await familyService.declineInvite(token: token)
      state = .declined
    } catch {
      logger.error("declineInvite: \(error.localizedDescription)")
      errorMessage = "Failed to decline invite. Please try again."
    }
  }


}
