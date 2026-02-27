import Foundation

struct User: Codable, Identifiable {
  let id: String
  let email: String
  let emailConfirmedAt: String?
  let phone: String?
  let fullName: String?
  let createdAt: String
  let updatedAt: String
  let role: UserRole?

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case emailConfirmedAt = "email_confirmed_at"
    case phone
    case fullName = "full_name"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case role
  }

  init(
    id: String,
    email: String,
    emailConfirmedAt: String?,
    phone: String?,
    fullName: String? = nil,
    createdAt: String,
    updatedAt: String,
    role: UserRole?
  ) {
    self.id = id
    self.email = email
    self.emailConfirmedAt = emailConfirmedAt
    self.phone = phone
    self.fullName = fullName
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.role = role
  }
}
