import Foundation

/// Errors that can occur during College Scorecard API lookup
enum CollegeDataError: LocalizedError {
  case nameTooShort
  case apiKeyMissing
  case sessionMissing
  case invalidApiKey
  case rateLimited
  case schoolNotFound
  case invalidResponse
  case serverError(Int)
  case networkError(Error)

  var errorDescription: String? {
    switch self {
    case .nameTooShort:
      return "School name must be at least 3 characters"
    case .apiKeyMissing:
      return "College Scorecard API is not configured"
    case .sessionMissing:
      return "You must be signed in to search colleges"
    case .invalidApiKey:
      return "Invalid API key"
    case .rateLimited:
      return "Too many requests. Please try again in a few moments."
    case .schoolNotFound:
      return "School not found in College Scorecard database"
    case .invalidResponse:
      return "Invalid response from College Scorecard API"
    case .serverError(let code):
      return "Server error (\(code)). Please try again later."
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .nameTooShort:
      return "Try entering the full school name."
    case .apiKeyMissing:
      return "Contact support to configure API access."
    case .sessionMissing:
      return "Sign in and try again."
    case .invalidApiKey:
      return "Contact support to update API credentials."
    case .rateLimited:
      return "Wait a few moments before trying again."
    case .schoolNotFound:
      return "Try different spelling or enter data manually."
    case .invalidResponse, .serverError:
      return "Try again later or enter data manually."
    case .networkError:
      return "Check your internet connection and try again."
    }
  }
}
