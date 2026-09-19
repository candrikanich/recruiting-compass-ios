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

  nonisolated deinit {}
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
  var signupDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
  var signupPassword: String = ""
  var signupConfirmPassword: String = ""
  var signupAgreeToTerms = false
  var signupError: String?

  // GET /api/family/invite/:token deliberately withholds emailExists (no
  // account-existence disclosure pre-acceptance — see InviteDetails), so it
  // always decodes false, defaulting every unauthenticated invitee to the
  // signup form. An existing user hitting that default gets a duplicate-
  // account error from signup with no way to switch to login (#151 review).
  // nil = use that default; an explicit value overrides it via the toggle
  // link in each section.
  var authModeOverride: Bool?

  private let token: String
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging
  private let preferenceService: any PreferenceManaging
  private let turnstileTokenProvider: any TurnstileTokenProviding

  var isAuthenticated: Bool { authManager.isAuthenticated }

  var inviteDetails: InviteDetails? {
    if case .loaded(let d) = state { return d }
    return nil
  }

  /// Whether the unauthenticated invitee should see the login form (vs.
  /// signup). Prefers the user's manual choice over the server's
  /// (deliberately always-false) emailExists hint.
  func showsLoginSection(for invite: InviteDetails) -> Bool {
    authModeOverride ?? invite.emailExists
  }

  init(
    token: String,
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil
  ) {
    self.token = token
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
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
        let captchaToken = try await turnstileTokenProvider.getToken()
        try await authManager.login(email: loginEmail, password: loginPassword, captchaToken: captchaToken)
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
      errorMessage = (error as? AuthError)?.errorDescription ?? "Failed to connect to family. Please try again."
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
      let captchaToken = try await turnstileTokenProvider.getToken()
      // Route the parent's prefill through the same pending_* metadata + flush-before-publish
      // guard self-signup step 1 uses, so the onboarding gate never observes an empty
      // primarySport and re-asks for what the parent already chose (see savePrefillPreferences).
      try await authManager.signup(
        email: invite.email,
        password: signupPassword,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil,
        graduationYear: invite.prefill?.graduationYear,
        primarySport: invite.prefill?.sport,
        gender: nil,
        zipCode: nil,
        captchaToken: captchaToken
      )
      try await familyService.acceptInvite(token: token)
      let prefillSaved = await savePrefillPreferences(from: invite.prefill)
      successMessage = "You're connected!"
      if inviteDetails?.emailMismatch == true {
        successMessage = "You're connected! (You used a different email than the invite.)"
      }
      if !prefillSaved {
        successMessage = "You're connected! We couldn't save your player details — you can add them later in Preferences."
      }
      showSuccessToast = true
      try? await Task.sleep(for: .milliseconds(1500))
      navigateToDashboard = true
    } catch {
      logger.error("signupAndConnect: \(error.localizedDescription)")
      signupError = (error as? AuthError)?.errorDescription ?? "Could not create account. Please try again."
    }
  }

  /// Sport and graduation year are passed into `authManager.signup(...)` instead (flushed
  /// before `isAuthenticated` publishes — see signupAndConnect), so this only needs to carry
  /// position, which has no equivalent signup-time slot.
  /// Returns false when the user's player details could not be persisted, so the
  /// caller can tell them instead of silently discarding what they entered.
  private func savePrefillPreferences(from prefill: InvitePrefill?) async -> Bool {
    guard let prefill, let position = prefill.position else { return true }
    do {
      var details: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) ?? .default
      details.primaryPosition = position
      _ = try await preferenceService.savePreferences(category: .player, data: details)
      logger.debug("Saved prefill player position from invite")
      return true
    } catch {
      logger.error("Failed to save prefill player position: \(error.localizedDescription)")
      return false
    }
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
