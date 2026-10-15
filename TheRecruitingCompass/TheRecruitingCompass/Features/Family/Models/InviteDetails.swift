import Foundation

/// Response from GET /api/family/invite/:token (public endpoint).
///
/// This endpoint is reachable by anyone with the link, not just the invitee —
/// server/api/family/invite/[token].get.ts deliberately withholds PII (the
/// inviter's name, whether the invited email already has an account) until
/// after acceptance proves ownership of the invited address. `inviterName`
/// and `emailExists` reflect that: optional/defaulted here, not required.
struct InviteDetails: Codable, Sendable, Equatable {
  let invitationId: String
  /// The invited email address. Server key is `invitedEmail`, not `email`.
  let email: String
  let role: String
  let familyName: String
  /// Server-resolved "<Player>'s Family" (shown pre-acceptance per the 2026-10-14 decision on ios#368); absent from
  /// API versions that predate web#1265.
  let familyLabel: String?
  /// Not sent by the current endpoint (PII withheld pre-acceptance) — nil
  /// until/unless the server starts returning it again.
  let inviterName: String?
  /// When true, show login form; when false, show signup form. Not sent by
  /// the current endpoint — defaults to false (signup form).
  let emailExists: Bool
  /// Optional prefill from parent-entered player details (only for player invitees).
  let prefill: InvitePrefill?

  var displayLabel: String { FamilyLabel.display(label: familyLabel, legacyName: familyName) ?? familyName }

  /// Headline on the invite screen. Labels already read "Alex's Family"; the legacy name needs the possessive added.
  var headline: String {
    FamilyLabel.display(label: familyLabel, legacyName: nil).map { "Join \($0)" }
      ?? "\(familyName)'s recruiting journey"
  }

  var memberRole: UserRole? { UserRole(rawValue: role) }

  enum CodingKeys: String, CodingKey {
    case invitationId
    case email = "invitedEmail"
    case role
    case familyName
    case familyLabel
    case inviterName
    case emailExists
    case prefill
  }

  init(invitationId: String, email: String, role: String, familyName: String, familyLabel: String? = nil, inviterName: String? = nil, emailExists: Bool = false, prefill: InvitePrefill? = nil) {
    self.invitationId = invitationId
    self.email = email
    self.role = role
    self.familyName = familyName
    self.familyLabel = familyLabel
    self.inviterName = inviterName
    self.emailExists = emailExists
    self.prefill = prefill
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    invitationId = try c.decode(String.self, forKey: .invitationId)
    email = try c.decode(String.self, forKey: .email)
    role = try c.decode(String.self, forKey: .role)
    familyName = try c.decode(String.self, forKey: .familyName)
    familyLabel = try c.decodeIfPresent(String.self, forKey: .familyLabel)
    inviterName = try c.decodeIfPresent(String.self, forKey: .inviterName)
    emailExists = try c.decodeIfPresent(Bool.self, forKey: .emailExists) ?? false
    prefill = try c.decodeIfPresent(InvitePrefill.self, forKey: .prefill)
  }
}
