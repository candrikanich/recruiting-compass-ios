import Foundation

/// Errors from the invite join flow
enum InviteError: Error, LocalizedError, Equatable {
  case expired
  case alreadyAccepted
  case notFound
  case serverError(String)

  var errorDescription: String? {
    switch self {
    case .expired:
      return "This invite link has expired. Ask the sender to resend."
    case .alreadyAccepted:
      return "You're already connected to this family."
    case .notFound:
      return "This invite link is invalid or has already been used."
    case .serverError(let msg):
      return msg
    }
  }
}
