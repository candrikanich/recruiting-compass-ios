import Foundation

/// Guardian-confirmation state for the signed-in player. Mirrors web's
/// `GET /api/guardian/status` response shape exactly.
///
/// Never carries the claim `token` — that is the guardian's authorization to
/// consent, and handing it to the player would let a minor confirm their own
/// account.
struct GuardianStatus: Decodable, Equatable, Sendable {
  /// True when outbound features (coach messaging, profile publishing) stay
  /// locked. Use this for enforcement — `status` is presentation-only (see
  /// server/api/guardian/status.get.ts). The server also still sends a
  /// deprecated `pending` field (kept only for an older iOS build reading it
  /// directly); this client no longer decodes it, see planning/iOS_SPEC_web-
  /// ios-parity-pass-2026-09-17.md Item 5 (web repo).
  let locked: Bool
  /// Obfuscated for display (e.g. "j***@example.com"); the full address is
  /// never returned to the player.
  let guardianEmailMasked: String?
  let expiresAt: String?
  let status: String?
}

/// What a guardian sees when resolving a claim token, before they've
/// confirmed. Mirrors web's `GET /api/guardian/claim/[token]` response.
struct GuardianClaimDetails: Decodable, Equatable, Sendable {
  let guardianEmail: String
  let playerName: String
  let playerDateOfBirth: String?
  let playerGraduationYear: Int?
  let expiresAt: String
}

/// Response from `POST /api/auth/signup-minor`.
struct SignupMinorResult: Decodable, Equatable, Sendable {
  let ok: Bool
  /// `nil` when the player skipped naming a guardian — see
  /// server/api/auth/signup-minor.post.ts's `guardianEmail: null` response.
  let guardianEmail: String?
  let guardianEmailSent: Bool
}

/// Response from `POST /api/guardian/claim/[token]/accept`.
struct GuardianClaimAcceptResult: Decodable, Equatable, Sendable {
  let success: Bool
  let familyUnitId: String?
}
