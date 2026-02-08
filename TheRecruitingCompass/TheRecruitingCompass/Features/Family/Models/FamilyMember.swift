import Foundation

struct FamilyMember: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let familyUnitId: String
  let role: String
  let firstName: String?
  let lastName: String?
  let email: String
  let createdAt: String

  var fullName: String {
    if let first = firstName, let last = lastName {
      return "\(first) \(last)"
    }
    return email.components(separatedBy: "@").first?.capitalized ?? "Unknown"
  }

  var isAthlete: Bool {
    role == "athlete"
  }

  var isParent: Bool {
    role == "parent"
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case role
    case firstName = "first_name"
    case lastName = "last_name"
    case email
    case createdAt = "created_at"
  }
}
