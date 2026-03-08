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
  let dateOfBirth: String?
  let profilePhotoUrl: String?

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case emailConfirmedAt = "email_confirmed_at"
    case phone
    case fullName = "full_name"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case role
    case dateOfBirth = "date_of_birth"
    case profilePhotoUrl = "profile_photo_url"
  }

  init(
    id: String,
    email: String,
    emailConfirmedAt: String?,
    phone: String?,
    fullName: String? = nil,
    createdAt: String,
    updatedAt: String,
    role: UserRole?,
    dateOfBirth: String? = nil,
    profilePhotoUrl: String? = nil
  ) {
    self.id = id
    self.email = email
    self.emailConfirmedAt = emailConfirmedAt
    self.phone = phone
    self.fullName = fullName
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.role = role
    self.dateOfBirth = dateOfBirth
    self.profilePhotoUrl = profilePhotoUrl
  }
}
