import Foundation

/// Domain-specific authentication errors thrown by `AuthManager` and surfaced to the UI.
///
/// All cases provide user-facing `errorDescription` and `recoverySuggestion` strings
/// via `LocalizedError` conformance.
enum AuthError: LocalizedError {
  /// The supplied email address does not match a valid format.
  case invalidEmail
  /// The password contains fewer than 8 characters.
  case passwordTooShort
  /// The email or password did not match any account.
  case invalidCredentials
  /// A network-layer failure; the associated value contains a human-readable description.
  case networkError(String)
  /// The backend returned an unexpected error; the associated value contains details.
  case serverError(String)
  /// The account was temporarily locked after too many failed login attempts.
  /// - Parameter retryAfter: Localised time string indicating when the lock lifts, or `nil` if unknown.
  case tooManyAttempts(retryAfter: String?)
  /// No account was found for the given email address.
  case userNotFound
  /// The account exists but the email address has not been verified.
  case emailNotVerified
  /// An account already exists for this email address.
  case emailAlreadyRegistered
  /// The password does not meet the minimum strength requirements.
  case passwordTooWeak
  /// The confirmation password field does not match the primary password field.
  case passwordsDoNotMatch
  /// The family invite code is malformed or does not match any active family unit.
  case invalidFamilyCode
  /// The user did not accept the terms and conditions before proceeding.
  case termsNotAccepted
  /// The password-reset deep-link token is not recognised by the backend.
  case invalidResetToken
  /// The password-reset deep-link token has passed its expiry window.
  case expiredResetToken
  /// No account was found for the given email during a password-reset request.
  case resetEmailNotFound
  /// The stored session is no longer valid and the user must sign in again.
  case sessionInvalid
  /// The user's date of birth places them below the COPPA minimum age of 13.
  case coppaUnderAge
  /// An unexpected error occurred; the associated value wraps the underlying `Error`.
  case unknown(Error)

  var errorDescription: String? {
    switch self {
    case .invalidEmail:
      return "Invalid email address"
    case .passwordTooShort:
      return "Password must be at least 8 characters"
    case .invalidCredentials:
      return "Invalid email or password"
    case .networkError(let message):
      return message
    case .serverError:
      return "Server error. Please try again later."
    case .tooManyAttempts(let retryAfter):
      if let retryAfter {
        return "Too many login attempts. Please try again \(retryAfter)"
      }
      return "Too many login attempts. Please try again later."
    case .userNotFound:
      return "Email not found. Please sign up first."
    case .emailNotVerified:
      return "Please verify your email. Check your inbox for a verification link."
    case .emailAlreadyRegistered:
      return "An account with this email already exists"
    case .passwordTooWeak:
      return "Password does not meet strength requirements"
    case .passwordsDoNotMatch:
      return "Passwords do not match"
    case .invalidFamilyCode:
      return "Invalid family code format or code not found"
    case .termsNotAccepted:
      return "You must accept the terms and conditions"
    case .invalidResetToken:
      return "This password reset link is invalid."
    case .expiredResetToken:
      return "This password reset link has expired."
    case .resetEmailNotFound:
      return "If an account exists for this email, you will receive a reset link shortly."
    case .sessionInvalid:
      return "Your session is no longer valid. Please sign in again."
    case .coppaUnderAge:
      return "You must be at least 13 years old to create an account."
    case .unknown(let err):
      let msg = err.localizedDescription.trimmingCharacters(in: .whitespaces)
      if msg.isEmpty || msg.contains("The operation couldn't be completed") {
        return "An unexpected error occurred. Please try again."
      }
      return msg
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .invalidEmail, .passwordTooShort, .invalidCredentials:
      return "Please check your email and password and try again."
    case .networkError:
      return "Check your internet connection and try again."
    case .serverError:
      return "Try again later or contact support if the problem persists."
    case .tooManyAttempts:
      return "Wait a few minutes before trying again."
    case .userNotFound:
      return "Create a new account to get started."
    case .emailNotVerified:
      return "Resend the verification email if you don't see it in your inbox."
    case .emailAlreadyRegistered:
      return "Try logging in with this email or use a different email to sign up."
    case .passwordTooWeak:
      return "Use a stronger password with uppercase, lowercase, numbers, and 8+ characters."
    case .passwordsDoNotMatch:
      return "Make sure both passwords are identical."
    case .invalidFamilyCode:
      return "Check the family code format or confirm it with the family administrator."
    case .termsNotAccepted:
      return "Please accept the terms and conditions to continue."
    case .invalidResetToken:
      return "Request a new password reset link."
    case .expiredResetToken:
      return "Request a new password reset link to continue."
    case .resetEmailNotFound:
      return "Check the email address or create a new account."
    case .sessionInvalid:
      return "Sign out and create a new account to continue."
    case .coppaUnderAge:
      return "Accounts are for users 13 and older. A parent or guardian can create an account and invite you."
    case .unknown:
      return "Please try again or contact support."
    }
  }
}
