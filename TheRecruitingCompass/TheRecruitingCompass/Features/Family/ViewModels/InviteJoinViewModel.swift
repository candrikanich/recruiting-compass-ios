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

  // Shown after signupAndConnect() succeeds for a player invite, letting the player confirm (or
  // correct) the birthday their parent entered during onboarding before landing on the dashboard.
  var showBirthdayConfirmStep = false
  var confirmedDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
  var dateOfBirthWasPrefilled = false
  var birthdayConfirmError: String?
  var isConfirmingBirthday = false

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
  private let turnstileTokenProvider: any TurnstileTokenProviding
  private let profileService: any ProfileManaging

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
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil,
    profileService: (any ProfileManaging)? = nil
  ) {
    self.token = token
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
    self.profileService = profileService ?? ProfileServiceImpl(supabaseManager: .shared)
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
      if authManager.isAuthenticated {
        try await familyService.acceptInvite(token: token)
      } else {
        let captchaToken = try await turnstileTokenProvider.getToken()
        // Accepting the invite must run BEFORE authManager publishes isAuthenticated: it's what
        // triggers the server's hydrateAthleteFromPendingDetails() write (sport/gradYear/position
        // into the same user_preferences row iOS reads), and the onboarding gate reads that row
        // the instant isAuthenticated flips true. See signupAndConnect()'s matching comment.
        // beforePublish is throwing: a failed acceptInvite aborts login() itself, so
        // isAuthenticated never publishes true for an invite that didn't actually get accepted.
        try await authManager.login(
          email: loginEmail, password: loginPassword, captchaToken: captchaToken,
          beforePublish: { [weak self] in
            guard let self else { return }
            try await self.familyService.acceptInvite(token: self.token)
          }
        )
      }
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
    dobFormatter.locale = Locale(identifier: "en_US_POSIX")
    dobFormatter.timeZone = TimeZone(secondsFromGMT: 0)
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

    var acceptResponse: AcceptInviteResponse?
    do {
      let fullName = "\(first) \(last)"
      let captchaToken = try await turnstileTokenProvider.getToken()
      // Accepting the invite must run BEFORE authManager publishes isAuthenticated: it's what
      // triggers the server's hydrateAthleteFromPendingDetails() write (sport/gradYear/position
      // into the same user_preferences row iOS reads), and the onboarding gate reads that row
      // the instant isAuthenticated flips true. The unauthenticated invite-preview lookup
      // (loadInvite/InviteDetails.prefill) never carries this player data — Athlete PII is only
      // released here, after the authenticated caller has proven they're the invitee — so there
      // is nothing for signupAndConnect to pass into signup()'s own pending_* metadata.
      // beforePublish is throwing: a failed acceptInvite aborts signup() itself, so
      // isAuthenticated never publishes true for an invite that didn't actually get accepted.
      try await authManager.signup(
        email: invite.email,
        password: signupPassword,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil,
        graduationYear: nil,
        primarySport: nil,
        gender: nil,
        zipCode: nil,
        captchaToken: captchaToken,
        // This account's email_verified_at is stamped by acceptInvite() in beforePublish
        // below the instant the invite is accepted — skip the verify-email flow entirely
        // (mirrors web's join.vue invite-signup call), matching accept.post.ts:103-111.
        skipVerificationEmail: true,
        beforePublish: { [weak self] in
          guard let self else { return }
          acceptResponse = try await self.familyService.acceptInvite(token: self.token)
        }
      )

      successMessage = "You're connected!"
      if inviteDetails?.emailMismatch == true {
        successMessage = "You're connected! (You used a different email than the invite.)"
      }
      showSuccessToast = true
      try? await Task.sleep(for: .milliseconds(1500))

      if role == .player {
        prefillBirthdayConfirmStep(from: acceptResponse)
        showBirthdayConfirmStep = true
      } else {
        navigateToDashboard = true
      }
    } catch {
      logger.error("signupAndConnect: \(error.localizedDescription)")
      signupError = (error as? AuthError)?.errorDescription ?? "Could not create account. Please try again."
    }
  }

  private func prefillBirthdayConfirmStep(from response: AcceptInviteResponse?) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    if let dobString = response?.prefill?.dateOfBirth, let date = formatter.date(from: dobString) {
      confirmedDateOfBirth = date
      dateOfBirthWasPrefilled = true
    } else {
      // No parent-entered value to prefill — fall back to whatever the player already
      // entered (or left at the default) on the signup form.
      confirmedDateOfBirth = signupDateOfBirth
      dateOfBirthWasPrefilled = false
    }
  }

  /// Persists the (possibly edited) confirmed birthday, then proceeds to the dashboard.
  /// Fails open on a network/server error — a DOB PATCH failure should never strand the
  /// player on this screen.
  func confirmBirthday() async {
    birthdayConfirmError = nil

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let dobString = formatter.string(from: confirmedDateOfBirth)

    if COPPAHelper.isUnderAge(dobString) {
      birthdayConfirmError = "Players must be 13 or older"
      return
    }

    isConfirmingBirthday = true
    defer { isConfirmingBirthday = false }

    do {
      let fullName = "\(signupFirstName.trimmingCharacters(in: .whitespaces)) \(signupLastName.trimmingCharacters(in: .whitespaces))"
      try await profileService.updatePersonalInfo(fullName: fullName, dateOfBirth: dobString)
    } catch {
      logger.error("confirmBirthday: failed to persist DOB, continuing anyway: \(error.localizedDescription)")
    }

    showBirthdayConfirmStep = false
    navigateToDashboard = true
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
