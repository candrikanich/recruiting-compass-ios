import Foundation

struct User: Codable, Identifiable {
  let id: String
  let email: String
  let emailConfirmedAt: String?
  let phone: String?
  let userMetadata: [String: AnyCodable]?
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case emailConfirmedAt = "email_confirmed_at"
    case phone
    case userMetadata = "user_metadata"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

// Support for nested JSON objects in metadata
struct AnyCodable: Codable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intVal = try? container.decode(Int.self) {
      value = intVal
    } else if let doubleVal = try? container.decode(Double.self) {
      value = doubleVal
    } else if let boolVal = try? container.decode(Bool.self) {
      value = boolVal
    } else if let stringVal = try? container.decode(String.self) {
      value = stringVal
    } else if let arrayVal = try? container.decode([AnyCodable].self) {
      value = arrayVal
    } else if let dictVal = try? container.decode([String: AnyCodable].self) {
      value = dictVal
    } else {
      value = NSNull()
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let val as Int:
      try container.encode(val)
    case let val as Double:
      try container.encode(val)
    case let val as Bool:
      try container.encode(val)
    case let val as String:
      try container.encode(val)
    case let val as [AnyCodable]:
      try container.encode(val)
    case let val as [String: AnyCodable]:
      try container.encode(val)
    default:
      try container.encodeNil()
    }
  }
}
