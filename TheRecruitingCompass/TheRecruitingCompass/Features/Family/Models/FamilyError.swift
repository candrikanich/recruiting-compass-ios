import Foundation

enum FamilyError: LocalizedError {
  case notAuthenticated
  case invalidCode
  case alreadyMember
  case notFound
  case serverError(String)

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "You must be logged in to perform this action"
    case .invalidCode:
      return "Invalid family code format. Codes look like FAM-XXXXXX"
    case .alreadyMember:
      return "You are already a member of this family"
    case .notFound:
      return "Family code not found. Please check and try again"
    case .serverError(let message):
      return message
    }
  }
}
