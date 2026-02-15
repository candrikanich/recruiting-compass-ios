import Foundation

struct User: Codable, Identifiable {
  let id: String
  let email: String
  let emailConfirmedAt: String?
  let phone: String?
  let createdAt: String
  let updatedAt: String
  let role: UserRole?

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case emailConfirmedAt = "email_confirmed_at"
    case phone
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case role
  }
}
