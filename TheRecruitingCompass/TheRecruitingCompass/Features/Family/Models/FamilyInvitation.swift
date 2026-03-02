import Foundation

struct FamilyInvitation: Codable, Identifiable, Sendable {
  let id: String
  let familyUnitId: String?
  let invitedBy: String?
  let invitedEmail: String
  let role: String
  let token: String?
  let status: String
  let expiresAt: String?
  let createdAt: String?
  let acceptedAt: String?
  let declinedAt: String?

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
    case declinedAt = "declined_at"
  }

  init(id: String, familyUnitId: String?, invitedBy: String?, invitedEmail: String, role: String, token: String?, status: String, expiresAt: String?, createdAt: String?, acceptedAt: String?, declinedAt: String?) {
    self.id = id
    self.familyUnitId = familyUnitId
    self.invitedBy = invitedBy
    self.invitedEmail = invitedEmail
    self.role = role
    self.token = token
    self.status = status
    self.expiresAt = expiresAt
    self.createdAt = createdAt
    self.acceptedAt = acceptedAt
    self.declinedAt = declinedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    familyUnitId = try c.decodeIfPresent(String.self, forKey: .familyUnitId)
    invitedBy = try c.decodeIfPresent(String.self, forKey: .invitedBy)
    invitedEmail = try c.decode(String.self, forKey: .invitedEmail)
    role = try c.decode(String.self, forKey: .role)
    token = try c.decodeIfPresent(String.self, forKey: .token)
    status = try c.decode(String.self, forKey: .status)
    expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
    createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    acceptedAt = try c.decodeIfPresent(String.self, forKey: .acceptedAt)
    declinedAt = try c.decodeIfPresent(String.self, forKey: .declinedAt)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encodeIfPresent(familyUnitId, forKey: .familyUnitId)
    try c.encodeIfPresent(invitedBy, forKey: .invitedBy)
    try c.encode(invitedEmail, forKey: .invitedEmail)
    try c.encode(role, forKey: .role)
    try c.encodeIfPresent(token, forKey: .token)
    try c.encode(status, forKey: .status)
    try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
    try c.encodeIfPresent(createdAt, forKey: .createdAt)
    try c.encodeIfPresent(acceptedAt, forKey: .acceptedAt)
    try c.encodeIfPresent(declinedAt, forKey: .declinedAt)
  }

  var isPending: Bool { status == "pending" }
  var isExpired: Bool {
    guard let exp = expiresAt, !exp.isEmpty, let date = ISO8601DateFormatter().date(from: exp) else { return false }
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
  /// When true, logged-in email differs from invite email; accept still succeeds. Informational only.
  let emailMismatch: Bool?

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

/// Prefill data returned with invite when role is player and parent entered details.
struct InvitePrefill: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
  let sport: String?
  let position: String?
  let graduationYear: Int?

  enum CodingKeys: String, CodingKey {
    case firstName
    case lastName
    case sport
    case position
    case graduationYear
  }

  init(firstName: String, lastName: String, sport: String? = nil, position: String? = nil, graduationYear: Int? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.sport = sport
    self.position = position
    self.graduationYear = graduationYear
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    firstName = try c.decode(String.self, forKey: .firstName)
    lastName = try c.decode(String.self, forKey: .lastName)
    sport = try c.decodeIfPresent(String.self, forKey: .sport)
    position = try c.decodeIfPresent(String.self, forKey: .position)
    graduationYear = try c.decodeIfPresent(Int.self, forKey: .graduationYear)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(firstName, forKey: .firstName)
    try c.encode(lastName, forKey: .lastName)
    try c.encodeIfPresent(sport, forKey: .sport)
    try c.encodeIfPresent(position, forKey: .position)
    try c.encodeIfPresent(graduationYear, forKey: .graduationYear)
  }
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
