import Foundation

struct FamilyInvitation: Codable, Identifiable, Sendable {
  let id: String
  let familyUnitId: String?
  let invitedBy: String?
  let invitedEmail: String
  let role: String
  let token: String?
  let status: String
  let expiresAt: String
  let createdAt: String
  let acceptedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case familyUnitId = "family_unit_id"
    case invitedBy = "invited_by"
    case invitedEmail = "invited_email"
    case role
    case token
    case status
    case expiresAt = "expires_at"
    case createdAt = "created_at"
    case acceptedAt = "accepted_at"
  }

  var isPending: Bool { status == "pending" }
  var isExpired: Bool {
    guard let date = ISO8601DateFormatter().date(from: expiresAt) else { return false }
    return date < Date()
  }
}

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

  enum CodingKeys: String, CodingKey {
    case invitationId
    case email
    case role
    case familyName
    case inviterName
    case emailExists
    case prefill
  }

  init(invitationId: String, email: String, role: String, familyName: String, inviterName: String, emailExists: Bool = false, prefill: InvitePrefill? = nil) {
    self.invitationId = invitationId
    self.email = email
    self.role = role
    self.familyName = familyName
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
    inviterName = try c.decode(String.self, forKey: .inviterName)
    emailExists = try c.decodeIfPresent(Bool.self, forKey: .emailExists) ?? false
    prefill = try c.decodeIfPresent(InvitePrefill.self, forKey: .prefill)
  }
}

/// Prefill data returned with invite when role is player and parent entered details.
struct InvitePrefill: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
}

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
