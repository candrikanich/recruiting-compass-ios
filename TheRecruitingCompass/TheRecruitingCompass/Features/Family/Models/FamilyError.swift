import Foundation

enum FamilyError: LocalizedError {
  case notAuthenticated
  case invalidCode
  case alreadyMember
  case notFound
  case serverError(String)
  /// 409 last_member_confirmation_required: leaving deletes the family; resend with confirmDeleteFamily.
  case lastMemberConfirmationRequired(String)
  /// 409 family_busy_retry that outlived the automatic retry.
  case busyRetry(String)
  /// 409 on create. Future-proofing for the server guard tracked in web#1390 (not built yet); the client
  /// itself never offers Create while an invite is pending.
  case createConflict

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "You must be logged in to perform this action"
    case .invalidCode:
      return "Invalid Family Code format. Codes look like FAM-XXXXXX"
    case .alreadyMember:
      return "You are already a member of this family"
    case .notFound:
      return "Family Code not found. Please check and try again"
    case .createConflict:
      return "We found an existing family or invitation for your account. Checking again\u{2026}"
    case .serverError(let message), .lastMemberConfirmationRequired(let message), .busyRetry(let message):
      return message
    }
  }
}
