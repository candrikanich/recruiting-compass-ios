import Foundation

/// A Supabase user account, decoded from the auth API response.
///
/// Stored in Keychain between sessions and refreshed after `refreshSession()`.
struct User: Codable, Identifiable, Sendable {
  /// Supabase user UUID.
  let id: String
  /// The user's email address.
  let email: String
  /// ISO 8601 timestamp when the email was verified; `nil` if not yet confirmed.
  let emailConfirmedAt: String?
  /// Optional phone number associated with the account.
  let phone: String?
  /// Display name entered at signup.
  let fullName: String?
  /// ISO 8601 timestamp of account creation.
  let createdAt: String
  /// ISO 8601 timestamp of the most recent account update.
  let updatedAt: String
  /// The user's role within their family unit (athlete, parent, etc.).
  let role: UserRole?
  /// ISO 8601 date string used for COPPA age-gate enforcement; `nil` if not provided at signup.
  let dateOfBirth: String?
  /// URL to the profile photo stored in Supabase Storage; `nil` if no photo has been uploaded.
  let profilePhotoUrl: String?
  /// New User Experience progress JSON; `nil` if the user has never started the NUX checklist.
  let nuxProgress: NuxProgress?

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
    case nuxProgress = "nux_progress"
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
    profilePhotoUrl: String? = nil,
    nuxProgress: NuxProgress? = nil
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
    self.nuxProgress = nuxProgress
  }
}
