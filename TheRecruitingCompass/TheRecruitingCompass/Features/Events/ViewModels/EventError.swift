import Foundation

enum EventError: LocalizedError {
  case validationFailed

  var errorDescription: String? {
    switch self {
    case .validationFailed:
      return "Please complete all required fields"
    }
  }
}
