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
  /// Only shown/required for players aged 13-17 (see `isMinorSignup`).
  var guardianEmail = ""

  // Player-only onboarding step 1, captured here so a confirming player isn't re-asked.
  // See planning/iOS_SPEC_preconfirm-onboarding-step1-2026-09-11.md.
  var graduationYear: Int?
  var primarySport = ""
  var gender = ""
  var zipCode = ""

  // MARK: - UI State

  var isLoading = false
  var errorMessage: String?
  var fieldErrors: [FormFieldKey: String] = [:]
  var shouldNavigateToVerifyEmail = false

  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging
  private let guardianService: any GuardianManaging
  private let turnstileTokenProvider: any TurnstileTokenProviding
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
    let hasValidDOB = role == .player
      ? !COPPAHelper.isUnderAge(dobString)
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

    let guardianEmailValid = isMinorSignup
      ? formValidator.validateEmail(guardianEmail) == nil &&
        guardianEmail.trimmingCharacters(in: .whitespaces).lowercased() != email.trimmingCharacters(in: .whitespaces).lowercased()
      : true

    return hasValidFirstName &&
      hasValidLastName &&
      hasValidEmail &&
      hasValidPassword &&
      passwordsMatch &&
      termsChecked &&
      passwordStrengthValid &&
      hasValidDOB &&
      hasValidPlayerDetails &&
      familyCodeValid &&
      guardianEmailValid &&
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

  /// True when the player is under 13 (COPPA). Players 13+ can sign up independently.
  var isUnderCOPPAAge: Bool {
    selectedRole == .player && COPPAHelper.isUnderAge(dobString)
  }

  /// True for a 13-17 player: they self-signup and name a guardian instead of
  /// waiting to be invited by one (parity with web PR #784). 18+ players and
  /// parents are unaffected.
  var isMinorSignup: Bool {
    selectedRole == .player && COPPAHelper.requiresGuardianInvite(dobString)
  }

  init(
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil,
    guardianService: (any GuardianManaging)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.guardianService = guardianService ?? GuardianServiceImpl()
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
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

  func validateGuardianEmail() {
    guard isMinorSignup else {
      fieldErrors[.guardianEmail] = nil
      return
    }
    validate(.guardianEmail) {
      if let error = formValidator.validateEmail(guardianEmail) { return error }
      if guardianEmail.trimmingCharacters(in: .whitespaces).lowercased() ==
          email.trimmingCharacters(in: .whitespaces).lowercased() {
        return "Your parent or guardian needs a different email than yours"
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

  func signup() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    validateFirstName()
    validateLastName()
    validateEmail()
    if selectedRole == .player { validateDateOfBirth() }
    validatePassword()
    validateConfirmPassword()
    validateFamilyCode()
    validateZipCode()
    validateGuardianEmail()

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

    if isMinorSignup {
      await signupMinor()
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
        captchaToken: captchaToken
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

  /// Standalone signup for a 13-17 player who names a guardian, via the
  /// dedicated `signup-minor` endpoint (parity with web PR #784). No family
  /// is created here and no session is returned — the guardian's later
  /// confirmation creates the family unit and links the player into it.
  private func signupMinor() async {
    do {
      let captchaToken = try await turnstileTokenProvider.getToken()
      _ = try await guardianService.signupMinor(
        email: email,
        password: password,
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        dateOfBirth: dobString,
        guardianEmail: guardianEmail,
        captchaToken: captchaToken
      )
      shouldNavigateToVerifyEmail = true
    } catch {
      errorMessage = (error as? GuardianServiceError)?.errorDescription
        ?? mapAuthError(error).userMessage
    }
  }

  func dismissError() {
    errorMessage = nil
  }

}
