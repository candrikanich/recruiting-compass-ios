import Foundation

enum SuggestionsAPIError: LocalizedError, Equatable {
  case forbidden
  case unauthorized
  case notConfigured
  case invalidResponse
  case serverError(Int)
  case csrfFailed

  var errorDescription: String? {
    switch self {
    case .forbidden: return "You can't dismiss or complete action items when viewing another athlete's dashboard."
    case .unauthorized: return "Session expired. Pull to refresh or sign in again."
    case .notConfigured: return "Action items require API configuration."
    case .invalidResponse: return "Couldn't reach the server. Please try again."
    case .serverError: return "Server error. Please try again."
    case .csrfFailed: return "Couldn't reach the server. Please try again."
    }
  }
}
