import Foundation
import Helpers
import Supabase

// MARK: - User-Facing Messages

/// Maps a thrown error to a fixed message safe to show the user.
///
/// `localizedDescription` is deliberately never returned: it carries server and framework wording
/// that is neither written for our users nor localized for them. Log it instead, and surface one of
/// these strings.
///
/// - Parameters:
///   - fallback: Returned when nothing more specific applies. Should name the failed action.
///   - notFound: Returned for HTTP 404. Pass `nil` where the caller has no meaningful "missing" case.
///   - secureConnectionFailed: Returned for TLS trust failures. Pass `nil` to treat them as `fallback`.
func userFacingMessage(
  for error: Error,
  fallback: String,
  notFound: String? = nil,
  secureConnectionFailed: String? = nil
) -> String {
  if let urlError = error as? URLError {
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost:
      return "No internet connection. Please check your connection."
    case .timedOut:
      return "Connection timed out. Please try again."
    case .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
         .serverCertificateNotYetValid:
      if let secureConnectionFailed { return secureConnectionFailed }
    default:
      break
    }
  }

  if let notFound, (error as NSError).code == 404 {
    return notFound
  }

  return fallback
}

// MARK: - Database Error Classification

/// Postgres SQLSTATE for `foreign_key_violation`, surfaced by PostgREST in `PostgrestError.code`.
private let postgresForeignKeyViolationCode = "23503"

/// True when a write failed because another table still references the row — the signal to retry as
/// a cascade delete.
///
/// The typed PostgREST code is the reliable, locale-independent signal. Message matching stays as a
/// fallback for errors that reach us untyped: ones a service layer wrapped, and ones a trigger
/// raised with a custom message rather than as a constraint violation.
func isForeignKeyViolation(_ error: Error) -> Bool {
  if let postgrestError = error as? PostgrestError {
    return postgrestError.code == postgresForeignKeyViolationCode
  }

  let message = error.localizedDescription.lowercased()
  return message.contains("foreign key")
    || message.contains("still referenced")
    || message.contains("cannot delete")
}
