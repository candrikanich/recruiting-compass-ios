import Auth
import Foundation

/// Classifies errors thrown by Supabase Auth so callers can branch without reading error prose.
///
/// The typed `errorCode` is the locale-independent signal and is always preferred. Message matching
/// remains as a fallback for two cases we cannot rule out: GoTrue deployments old enough to omit
/// stable error codes, and errors that reach us wrapped rather than as a typed `Auth.AuthError`.
enum SupabaseAuthErrors {

  /// Supabase's `AuthError` shares its name with the app's own, so it must be module-qualified.
  private static func errorCode(of error: Error) -> Auth.ErrorCode? {
    (error as? Auth.AuthError)?.errorCode
  }

  static func isUserNotFound(_ error: Error) -> Bool {
    if let code = errorCode(of: error) {
      return code == .userNotFound
    }
    let description = error.localizedDescription.lowercased()
    return description.contains("not found") || description.contains("no user")
  }

  static func isInvalidToken(_ error: Error) -> Bool {
    if let code = errorCode(of: error) {
      switch code {
      case .badJWT, .invalidJWT, .badCodeVerifier, .flowStateNotFound:
        return true
      default:
        return false
      }
    }
    let description = error.localizedDescription.lowercased()
    return description.contains("invalid") || description.contains("token")
  }

  static func isExpiredToken(_ error: Error) -> Bool {
    if let code = errorCode(of: error) {
      switch code {
      case .sessionExpired, .otpExpired, .flowStateExpired:
        return true
      default:
        return false
      }
    }
    return error.localizedDescription.lowercased().contains("expired")
  }
}
