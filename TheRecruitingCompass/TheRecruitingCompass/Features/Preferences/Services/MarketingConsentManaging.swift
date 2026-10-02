import Foundation

/// Response of `GET`/`PATCH /api/user/marketing-consent` (web #1066). `eligible` is recomputed
/// server-side on every call (parent, or player 18+), so a player who turns 18 gains the toggle.
struct MarketingConsent: Decodable, Equatable, Sendable {
  let eligible: Bool
  let optIn: Bool
  /// ISO-8601 time of the last change in either direction; nil when never set.
  let updatedAt: String?
}

enum MarketingConsentError: Error, Equatable {
  case notConfigured
  case unauthenticated
  /// 403 — the server no longer considers this user marketing-eligible.
  case notEligible
  case server(Int)
}

protocol MarketingConsentManaging: Sendable {
  func fetchConsent() async throws -> MarketingConsent
  func updateConsent(optIn: Bool) async throws -> MarketingConsent
}
