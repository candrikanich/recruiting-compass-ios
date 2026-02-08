import Foundation

struct Coach: Codable, Identifiable, Sendable {
  let id: String
  let firstName: String
  let lastName: String
  let email: String?
  let phone: String?
  let position: String?
  let schoolId: String
  let createdAt: String
  let updatedAt: String

  var fullName: String {
    "\(firstName) \(lastName)"
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case email
    case phone
    case position
    case schoolId = "school_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
