import Foundation

/// Response from GET /api/family/invite/:token (public endpoint)
struct InviteDetails: Codable, Sendable, Equatable {
  let invitationId: String
  let email: String
  let role: String
  let familyName: String
  let inviterName: String
  /// When true, show login form; when false, show signup form.
  let emailExists: Bool
  /// Optional prefill from parent-entered player details (only for player invitees).
  let prefill: InvitePrefill?
  /// When true, logged-in email differs from invite email; accept still succeeds. Informational only.
  let emailMismatch: Bool?

  var memberRole: UserRole? { UserRole(rawValue: role) }

  enum CodingKeys: String, CodingKey {
    case invitationId
    case email
    case role
    case familyName
    case inviterName
    case emailExists
    case prefill
    case emailMismatch
  }

  init(invitationId: String, email: String, role: String, familyName: String, inviterName: String, emailExists: Bool = false, prefill: InvitePrefill? = nil, emailMismatch: Bool? = nil) {
    self.invitationId = invitationId
    self.email = email
    self.role = role
    self.familyName = familyName
    self.inviterName = inviterName
    self.emailExists = emailExists
    self.prefill = prefill
    self.emailMismatch = emailMismatch
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    invitationId = try c.decode(String.self, forKey: .invitationId)
    email = try c.decode(String.self, forKey: .email)
    role = try c.decode(String.self, forKey: .role)
    familyName = try c.decode(String.self, forKey: .familyName)
    inviterName = try c.decode(String.self, forKey: .inviterName)
    emailExists = try c.decodeIfPresent(Bool.self, forKey: .emailExists) ?? false
    prefill = try c.decodeIfPresent(InvitePrefill.self, forKey: .prefill)
    emailMismatch = try c.decodeIfPresent(Bool.self, forKey: .emailMismatch)
  }
}
