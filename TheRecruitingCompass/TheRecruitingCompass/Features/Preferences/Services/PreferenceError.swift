import Foundation

enum PreferenceError: LocalizedError {
  case notAuthenticated
  case invalidData
  case fetchFailed(String)
  case saveFailed(String)
  case deleteFailed(String)

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "You must be signed in to access preferences"
    case .invalidData:
      return "Invalid preference data format"
    case .fetchFailed(let message):
      return "Failed to load preferences: \(message)"
    case .saveFailed(let message):
      return "Failed to save preferences: \(message)"
    case .deleteFailed(let message):
      return "Failed to delete preferences: \(message)"
    }
  }
}
