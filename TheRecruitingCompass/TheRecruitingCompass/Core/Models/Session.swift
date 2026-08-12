import Foundation

/// A Supabase auth session containing JWT tokens and the associated user.
///
/// Persisted to Keychain so the session can be restored on next launch without re-authentication.
struct Session: Codable, Sendable {
  /// JWT used to authenticate Supabase RPC and web API requests.
  let accessToken: String
  /// Token scheme; always `"bearer"`.
  let tokenType: String
  /// Number of seconds until `accessToken` expires.
  let expiresIn: Int
  /// Unix timestamp (seconds since epoch) when `accessToken` expires.
  let expiresAt: Int
  /// Opaque token used to obtain a fresh `accessToken` without re-authentication.
  let refreshToken: String
  /// The user whose identity this session represents.
  let user: User

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case expiresIn = "expires_in"
    case expiresAt = "expires_at"
    case refreshToken = "refresh_token"
    case user
  }
}
