import Foundation

enum SuggestionsAPIError: Error, LocalizedError, Equatable {
  case forbidden
  case unauthorized

  var errorDescription: String? {
    switch self {
    case .forbidden: return "You can't dismiss or complete action items when viewing another athlete's dashboard."
    case .unauthorized: return "Session expired. Pull to refresh or sign in again."
    }
  }
}
