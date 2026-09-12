import Foundation
import OSLog
import SwiftUI
import Observation

private let signupLogger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SignupViewModel")

@Observable
@MainActor
final class SignupViewModel {

  nonisolated deinit {}
  // MARK: - Two-Step State

  var selectedRole: UserRole?
  var showForm = false

  // MARK: - Form Fields

  var firstName = ""
  var lastName = ""
  var email = ""
  var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -15, to: .now) ?? .now
  var password = ""
  var confirmPassword = ""
  var familyCode = ""
  var termsAccepted = false

  // Player-only onboarding step 1, captured here so a confirming player isn't re-asked.
  // See planning/iOS_SPEC_preconfirm-onboarding-step1-2026-09-11.md.
  var graduationYear: Int?
  var primarySport = ""
  var gender = ""
  var zipCode = ""

  /// Parent/guardian address a 13-17 player names at signup. Required only in that band.
  var guardianEmail = ""

  // MARK: - UI State

  var isLoading = false
  var errorMessage: String?
  var fieldErrors: [FormFieldKey: String] = [:]
  var shouldNavigateToVerifyEmail = false

  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging
  private let turnstileTokenProvider: any TurnstileTokenProviding
  private let guardianClaimService: any GuardianClaimServicing
  private let formValidator = FormValidator.self

  private var trimmedFirstName: String {
    firstName.trimmingCharacters(in: .whitespaces)
  }

  private var trimmedLastName: String {
    lastName.trimmingCharacters(in: .whitespaces)
  }

  /// Combined full name sent to the backend (Supabase `full_name`).
  /// Mirrors web behavior where first and last name fields are concatenated.
  var fullName: String {
    switch (trimmedFirstName.isEmpty, trimmedLastName.isEmpty) {
    case (false, false):
      return "\(trimmedFirstName) \(trimmedLastName)"
    case (false, true):
      return trimmedFirstName
    case (true, false):
      return trimmedLastName
    default:
      return ""
    }
  }

  private static let dobFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private var dobString: String {
    Self.dobFormatter.string(from: dateOfBirth)
  }

  var isFormValid: Bool {
    guard let role = selectedRole else { return false }

    let hasValidFirstName = !trimmedFirstName.isEmpty
    let hasValidLastName = !trimmedLastName.isEmpty
    let hasValidEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
    let hasValidPassword = !password.isEmpty
    let passwordsMatch = password == confirmPassword
    let termsChecked = termsAccepted
    let passwordStrengthValid = formValidator.validatePasswordStrength(password).isValid
    // DOB is only required for players (COPPA); parents don't provide their own DOB at signup.
    // Players must be 13+ (COPPA). A 13-17 player may sign up, but only by naming a
    // guardian who confirms the account — see `submitMinorSignup`.
    let hasValidDOB = role == .player ? !COPPAHelper.isUnderAge(dobString) : true
    let hasValidGuardianEmail = requiresGuardianInvite
      ? guardianClaimService.isConfigured
        && formValidator.validateEmail(guardianEmail) == nil
        && guardianEmail.trimmingCharacters(in: .whitespaces).lowercased()
          != email.trimmingCharacters(in: .whitespaces).lowercased()
      : true
    // Grad year + primary sport are required for players, same as DOB — mirrors web's
    // onboardingStep1 guard (both must be present, gender/zip stay optional).
    let hasValidPlayerDetails = role == .player
      ? graduationYear != nil && !primarySport.isEmpty
      : true
    let noFieldErrors = fieldErrors.isEmpty

    let familyCodeValid = if role.requiresFamilyCode {
      familyCode.trimmingCharacters(in: .whitespaces).isEmpty ||
        formValidator.validateFamilyCode(familyCode) == nil
    } else {
      true
    }

    return hasValidFirstName &&
      hasValidLastName &&
      hasValidEmail &&
      hasValidPassword &&
      passwordsMatch &&
      termsChecked &&
      passwordStrengthValid &&
      hasValidDOB &&
      hasValidGuardianEmail &&
      hasValidPlayerDetails &&
      familyCodeValid &&
      noFieldErrors
  }

  private var trimmedZipCode: String {
    zipCode.trimmingCharacters(in: .whitespaces)
  }

  /// True when both grad year and sport are drafted — the point at which signup should
  /// carry the `pending_*` onboarding-step-1 metadata (mirrors web's `onboardingStep1` guard).
  var hasDraftedOnboardingStep1: Bool {
    graduationYear != nil && !primarySport.isEmpty
  }

  /// Silently auto-derived gender for sports with an unambiguous NCAA classification
  /// (e.g. Baseball → male). `nil` for neutral sports, where the user's own selection is used.
  var derivedGender: String? {
    SportGenderMap.gender(for: primarySport).genderRawValue
  }

  /// Values threaded into `EmailVerificationView` to personalize the waiting copy.
  var draftedPrimarySport: String? { hasDraftedOnboardingStep1 ? primarySport : nil }
  var draftedGraduationYear: Int? { hasDraftedOnboardingStep1 ? graduationYear : nil }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  /// True when the player is under 13 (COPPA).
  var isUnderCOPPAAge: Bool {
    selectedRole == .player && COPPAHelper.isUnderAge(dobString)
  }

  /// True when this build can reach the web API, and so can offer the minor signup path
  /// at all. Without `API_BASE_URL` the endpoint is unreachable, and showing a field that
  /// cannot submit would be worse than saying so.
  var canSubmitMinorSignup: Bool { guardianClaimService.isConfigured }

  /// True when the player is 13-17 — old enough for an account, but only one a parent or
  /// guardian confirms (DB: `trg_enforce_minor_requires_invite`).
  var requiresGuardianInvite: Bool {
    selectedRole == .player && COPPAHelper.requiresGuardianInvite(dobString)
  }

  /// Guidance shown with the guardian-email field while the player is 13-17. Deliberately
  /// not a `fieldErrors` entry: the picker defaults to a 15-year-old, so this is the
  /// opening state for most players rather than a mistake they made.
  ///
  /// Copy mirrors web's callout in `components/Auth/SignupForm.vue`.
  var guardianInviteMessage: String? {
    guard requiresGuardianInvite else { return nil }
    guard guardianClaimService.isConfigured else {
      // No API_BASE_URL in this build, so the minor signup endpoint is unreachable. Say so
      // plainly rather than presenting a field that cannot submit.
      return "Signing up as a player under 18 isn't available in this build. "
        + "Ask a parent or guardian to create an account and send you a family invite."
    }
    return "You're under 18, so a parent or guardian needs to confirm your account. "
      + "We'll email them a link. You can start building your school list right away — "
      + "messaging coaches unlocks once they confirm."
  }

  init(
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil,
    guardianClaimService: (any GuardianClaimServicing)? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
    self.guardianClaimService = guardianClaimService ?? GuardianClaimServiceImpl()
  }

  // MARK: - Two-Step Flow

  func selectRole(_ role: UserRole) {
    selectedRole = role
    withAnimation { showForm = true }
  }

  func backToRoleSelection() {
    withAnimation { showForm = false }
    resetFormState()
  }

  private func resetFormState() {
    firstName = ""
    lastName = ""
    email = ""
    dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now) ?? .now
    password = ""
    confirmPassword = ""
    familyCode = ""
    termsAccepted = false
    graduationYear = nil
    primarySport = ""
    gender = ""
    zipCode = ""
    fieldErrors = [:]
    errorMessage = nil
  }

  // MARK: - Validation

  private func validate(_ field: FormFieldKey, using validator: () -> String?) {
    fieldErrors[field] = validator()
  }

  func validateFirstName() { validate(.firstName) { formValidator.validateName(trimmedFirstName) } }
  func validateLastName() { validate(.lastName) { formValidator.validateName(trimmedLastName) } }
  func validateEmail() { validate(.email) { formValidator.validateEmail(email) } }

  func validateDateOfBirth() {
    validate(.dateOfBirth) {
      if COPPAHelper.isUnderAge(dobString) {
        return "You must be 13 or older to create an account"
      }
      return nil
    }
  }

  func validatePassword() {
    validate(.password) {
      formValidator.validatePasswordStrength(password).isValid
        ? nil
        : "Password does not meet strength requirements"
    }
  }

  func validateConfirmPassword() {
    validate(.confirmPassword) { formValidator.validatePasswordMatch(password, confirmPassword) }
  }

  func validateGuardianEmail() {
    guard requiresGuardianInvite else {
      fieldErrors[.guardianEmail] = nil
      return
    }
    validate(.guardianEmail) {
      let trimmed = guardianEmail.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { return nil }  // Emptiness is conveyed by the disabled button.
      if let formatError = formValidator.validateEmail(trimmed) { return formatError }
      // A minor cannot be their own guardian — otherwise they receive their own consent
      // link. Server-enforced too; this is the fast feedback.
      if trimmed.lowercased() == email.trimmingCharacters(in: .whitespaces).lowercased() {
        return "Your parent or guardian needs a different email address than yours"
      }
      return nil
    }
  }

  func validateFamilyCode() {
    guard let role = selectedRole, role.requiresFamilyCode else {
      fieldErrors[.familyCode] = nil
      return
    }
    validate(.familyCode) { formValidator.validateFamilyCode(familyCode) }
  }

  /// Zip is optional; when present it must be 5 numeric digits. Mirrors the same rule
  /// `OnboardingV2ViewModel.saveStep1()` already enforces for the same field.
  func validateZipCode() {
    validate(.zipCode) {
      guard !trimmedZipCode.isEmpty else { return nil }
      guard trimmedZipCode.count == 5, trimmedZipCode.allSatisfy(\.isNumber) else {
        return "Enter a valid 5-digit zip code"
      }
      return nil
    }
  }

  func errorBinding(for key: FormFieldKey) -> Binding<String?> {
    Binding(
      get: { self.fieldErrors[key] },
      set: { self.fieldErrors[key] = $0 }
    )
  }

  func validateTerms() {
    if !termsAccepted {
      errorMessage = "You must accept the terms and conditions"
    } else {
      errorMessage = nil
    }
  }

  // MARK: - Actions

  /// Signup for a 13-17 player, who names a guardian to confirm the account.
  ///
  /// Routed through `POST /api/auth/signup-minor` rather than `AuthManager.signup`: the
  /// guardian_claims row has to exist before the DOB-bearing `users` write, and that table
  /// is service-role only. `AuthManager`'s standalone-minor guard still covers the direct
  /// path, so a regression here fails loudly rather than orphaning an auth user.
  private func submitMinorSignup() async {
    do {
      let captchaToken = try await turnstileTokenProvider.getToken()
      let draftsStep1 = hasDraftedOnboardingStep1
      try await guardianClaimService.signupMinor(
        MinorSignupInput(
          email: email.trimmingCharacters(in: .whitespaces),
          password: password,
          firstName: trimmedFirstName,
          lastName: trimmedLastName,
          dateOfBirth: dobString,
          guardianEmail: guardianEmail.trimmingCharacters(in: .whitespaces).lowercased(),
          graduationYear: draftsStep1 ? graduationYear : nil,
          primarySport: draftsStep1 ? primarySport : nil,
          gender: draftsStep1 ? (derivedGender ?? (gender.isEmpty ? nil : gender)) : nil,
          zipCode: draftsStep1 && !trimmedZipCode.isEmpty ? trimmedZipCode : nil,
          captchaToken: captchaToken
        )
      )

      // Same destination as an adult signup: email confirmation still gates the session,
      // and the guardian-pending state is surfaced on the dashboard once they're in.
      shouldNavigateToVerifyEmail = true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription
        ?? "Could not create the account. Please try again."
      signupLogger.error("Minor signup failed: \(error.localizedDescription)")
    }
    // isLoading is cleared by signup()'s `defer`, which owns the whole submit.
  }

  func signup() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    validateFirstName()
    validateLastName()
    validateEmail()
    if selectedRole == .player { validateDateOfBirth() }
    validateGuardianEmail()
    validatePassword()
    validateConfirmPassword()
    validateFamilyCode()
    validateZipCode()

    guard isFormValid else {
      if !fieldErrors.isEmpty {
        errorMessage = "Please fix the errors below"
      } else if !termsAccepted {
        errorMessage = "You must accept the terms and conditions"
      } else {
        errorMessage = "Please fix the errors below"
      }
      return
    }

    guard let role = selectedRole else {
      errorMessage = "Please select a role"
      return
    }

    // A 13-17 player goes through the web API instead of the browser-direct path: the
    // writes must be ordered against the DB's minor gate, and the guardian_claims row that
    // satisfies it is service-role only. Mirrors web's `submitMinorSignup`.
    if requiresGuardianInvite {
      await submitMinorSignup()
      return
    }

    do {
      let captchaToken = try await turnstileTokenProvider.getToken()
      // Only draft onboarding-step-1 metadata when both grad year and sport are present,
      // mirroring web's `onboardingStep1` guard (gender/zip alone are not enough).
      let draftsStep1 = role == .player && hasDraftedOnboardingStep1
      try await authManager.signup(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil,
        graduationYear: draftsStep1 ? graduationYear : nil,
        primarySport: draftsStep1 ? primarySport : nil,
        gender: draftsStep1 ? (derivedGender ?? (gender.isEmpty ? nil : gender)) : nil,
        zipCode: draftsStep1 && !trimmedZipCode.isEmpty ? trimmedZipCode : nil,
        captchaToken: captchaToken,
        // Standalone signup: a 13-17 player must not reach here (`isFormValid` blocks it).
        viaGuardianInvite: false
      )

      // Create family for both roles (mirrors web: POST /api/family/create)
      if authManager.isAuthenticated {
        do {
          _ = try await familyService.createFamily(role: role)
        } catch {
          // intentionally silent: signup itself succeeded and must not be blocked.
          // The dashboard onboarding banner detects the missing family and walks
          // the user through creating one, so that is the recovery surface.
          signupLogger.error("Family creation failed during signup: \(error.localizedDescription)")
        }
      }

      // Only show email verification when no session (e.g. confirmation required)
      if !authManager.isAuthenticated {
        shouldNavigateToVerifyEmail = true
      }
    } catch {
      errorMessage = mapAuthError(error).userMessage
    }
  }

  func dismissError() {
    errorMessage = nil
  }

}
