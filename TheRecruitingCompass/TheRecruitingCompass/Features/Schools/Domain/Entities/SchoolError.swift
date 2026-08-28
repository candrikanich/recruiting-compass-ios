import Foundation

enum SchoolError: LocalizedError {
  case invalidIndex

  var errorDescription: String? {
    "Invalid index. The item you're trying to access does not exist."
  }

  var recoverySuggestion: String? {
    "Please try again or refresh the list."
  }
}
