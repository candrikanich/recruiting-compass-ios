import Foundation

struct SchoolPreferences: Codable, Equatable, Sendable {
  var preferences: [SchoolPreference]
  var templateUsed: String?
  var lastUpdated: String?

  static var `default`: SchoolPreferences {
    SchoolPreferences(
      preferences: [],
      templateUsed: nil,
      lastUpdated: Date().ISO8601Format()
    )
  }

  enum CodingKeys: String, CodingKey {
    case preferences
    case templateUsed = "template_used"
    case lastUpdated = "last_updated"
  }
}

struct SchoolPreference: Codable, Equatable, Identifiable, Sendable {
  let id: String
  var category: PreferencePreferenceCategory
  var type: String
  var value: AnyCodableValue
  var priority: Int
  var isDealbreaker: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case category
    case type
    case value
    case priority
    case isDealbreaker = "is_dealbreaker"
  }
}

enum PreferencePreferenceCategory: String, Codable, Sendable {
  case location
  case academic
  case program
  case custom
}

/// Type-safe wrapper for heterogeneous JSON values in school preferences
enum AnyCodableValue: Codable, Equatable, Sendable {
  case string(String)
  case int(Int)
  case bool(Bool)
  case stringArray([String])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let stringArray = try? container.decode([String].self) {
      self = .stringArray(stringArray)
    } else if let intValue = try? container.decode(Int.self) {
      self = .int(intValue)
    } else if let boolValue = try? container.decode(Bool.self) {
      self = .bool(boolValue)
    } else if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else {
      throw DecodingError.typeMismatch(
        AnyCodableValue.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Value is not a supported type (String, Int, Bool, [String])"
        )
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .stringArray(let value):
      try container.encode(value)
    }
  }
}
