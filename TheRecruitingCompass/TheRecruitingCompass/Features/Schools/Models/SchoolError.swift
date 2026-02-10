import Foundation

enum SchoolError: LocalizedError {
  case invalidIndex
  case schoolNotFound
  case invalidStatus
  case invalidData
  case updateFailed(String)
  case deleteFailed(String)
  case unknown(Error)

  var errorDescription: String? {
    switch self {
    case .invalidIndex:
      return "Invalid index. The item you're trying to access does not exist."
    case .schoolNotFound:
      return "School not found."
    case .invalidStatus:
      return "Invalid status value."
    case .invalidData:
      return "Invalid data format."
    case .updateFailed(let message):
      return "Failed to update school: \(message)"
    case .deleteFailed(let message):
      return "Failed to delete school: \(message)"
    case .unknown(let error):
      return error.localizedDescription
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .invalidIndex:
      return "Please try again or refresh the list."
    case .schoolNotFound:
      return "Refresh the list and try again."
    case .invalidStatus:
      return "Please select a valid status."
    case .invalidData:
      return "Please check the data and try again."
    case .updateFailed, .deleteFailed:
      return "Check your internet connection and try again."
    case .unknown:
      return "Please try again or contact support."
    }
  }
}
