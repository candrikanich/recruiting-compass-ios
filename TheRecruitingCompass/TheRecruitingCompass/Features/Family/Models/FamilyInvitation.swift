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
