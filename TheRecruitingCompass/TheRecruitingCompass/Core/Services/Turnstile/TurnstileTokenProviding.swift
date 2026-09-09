import Foundation

/// Supplies single-use Cloudflare Turnstile tokens for Supabase Auth calls that require
/// captcha verification (login, signup, password reset). Conform for testability.
@MainActor
protocol TurnstileTokenProviding: AnyObject {
  /// Executes a fresh Turnstile challenge and returns its token. Never caches or reuses
  /// a token across calls — each Supabase auth call needs its own, tokens are single-use.
  func getToken() async throws -> String
}
