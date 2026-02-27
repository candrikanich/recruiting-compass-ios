import Foundation

struct AuthErrorMappingResult {
  let userMessage: String
  let isDismissible: Bool
  let requiresAction: Bool
}

func mapAuthError(_ error: Error) -> AuthErrorMappingResult {
  if let authError = error as? AuthError {
    return mapAuthErrorCases(authError)
  }

  // Show underlying message when available so network/config errors are clearer
  let message = error.localizedDescription
  let fallback = message.isEmpty || message.contains("The operation couldn't be completed")
    ? "An error occurred. Please try again."
    : message
  return AuthErrorMappingResult(
    userMessage: fallback,
    isDismissible: true,
    requiresAction: false
  )
}

private func mapAuthErrorCases(_ error: AuthError) -> AuthErrorMappingResult {
  let message = error.errorDescription ?? "An error occurred"

  switch error {
  case .resetEmailNotFound:
    return AuthErrorMappingResult(
      userMessage: message,
      isDismissible: true,
      requiresAction: true
    )

  case .networkError:
    return AuthErrorMappingResult(
      userMessage: message,
      isDismissible: true,
      requiresAction: false
    )

  case .invalidResetToken, .expiredResetToken:
    return AuthErrorMappingResult(
      userMessage: message,
      isDismissible: true,
      requiresAction: true
    )

  case .passwordTooWeak:
    return AuthErrorMappingResult(
      userMessage: message,
      isDismissible: true,
      requiresAction: true
    )

  default:
    return AuthErrorMappingResult(
      userMessage: message,
      isDismissible: true,
      requiresAction: false
    )
  }
}
