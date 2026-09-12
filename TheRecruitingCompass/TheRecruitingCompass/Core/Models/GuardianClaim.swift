import Foundation

/// Guardian-confirmation state for the signed-in player. Mirrors web's
/// `GET /api/guardian/status` response shape exactly.
///
/// Never carries the claim `token` — that is the guardian's authorization to
/// consent, and handing it to the player would let a minor confirm their own
/// account.
struct GuardianStatus: Decodable, Equatable, Sendable {
  /// True while an unconfirmed guardian claim is outstanding — outbound
  /// features (coach messaging, profile publishing) stay locked.
  let pending: Bool
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
  let guardianEmail: String
  let guardianEmailSent: Bool
}

/// Response from `POST /api/guardian/claim/[token]/accept`.
struct GuardianClaimAcceptResult: Decodable, Equatable, Sendable {
  let success: Bool
  let familyUnitId: String?
}
