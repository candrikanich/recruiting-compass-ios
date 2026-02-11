import Foundation

struct FamilyMemberUser: Codable, Sendable {
  let id: String
  let email: String
  let fullName: String?
  let role: String

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case fullName = "full_name"
    case role
  }
}
