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

  private static let isoFormatter = ISO8601DateFormatter()

  var isPending: Bool { status == "pending" }
  var isExpired: Bool {
    guard let exp = expiresAt, !exp.isEmpty, let date = Self.isoFormatter.date(from: exp) else { return false }
    return date < .now
  }
}
