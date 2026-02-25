import Foundation

enum AuthError: LocalizedError {
  case invalidEmail
  case passwordTooShort
  case invalidCredentials
  case networkError(String)
  case serverError(String)
  case tooManyAttempts(retryAfter: String?)
  case userNotFound
  case emailNotVerified
  case emailAlreadyRegistered
  case passwordTooWeak
  case passwordsDoNotMatch
  case invalidFamilyCode
  case termsNotAccepted
  case invalidResetToken
  case expiredResetToken
  case resetEmailNotFound
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
      if let retryAfter = retryAfter {
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
    case .unknown:
      return "An unexpected error occurred. Please try again."
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
    case .unknown:
      return "Please try again or contact support."
    }
  }
}
