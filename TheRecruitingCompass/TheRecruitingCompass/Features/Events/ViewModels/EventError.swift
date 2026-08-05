import Foundation

enum EventError: LocalizedError {
  case validationFailed

  var errorDescription: String? {
    switch self {
    case .validationFailed:
      return String(localized: "Please complete all required fields")
    }
  }
}
