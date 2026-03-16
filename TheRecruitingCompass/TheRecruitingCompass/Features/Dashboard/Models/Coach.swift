import Foundation

// Import CoachRole from Coaches feature
import SwiftUI

struct Coach: Codable, Identifiable, Sendable {
  let id: String
  let firstName: String
  let lastName: String
  let email: String?
  let phone: String?
  let position: String?
  let schoolId: String
  let twitterHandle: String?
  let instagramHandle: String?
  let notes: String?
  let responsivenessScore: Double
  let lastContactDate: String?
  let createdAt: String
  let updatedAt: String

  var fullName: String {
    "\(firstName) \(lastName)"
  }

  var initials: String {
    let first = firstName.prefix(1).uppercased()
    let last = lastName.prefix(1).uppercased()
    return "\(first)\(last)"
  }

  var role: CoachRole {
    guard let position else { return .assistant }
    return CoachRole(rawValue: position.lowercased()) ?? .assistant
  }

  private static let iso8601WithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let iso8601WithoutFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  var lastContactDateParsed: Date? {
    guard let dateString = lastContactDate else { return nil }
    return Coach.iso8601WithFractional.date(from: dateString)
      ?? Coach.iso8601WithoutFractional.date(from: dateString)
  }

  init(
    id: String,
    firstName: String,
    lastName: String,
    email: String? = nil,
    phone: String? = nil,
    position: String? = nil,
    schoolId: String,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil,
    responsivenessScore: Double,
    lastContactDate: String? = nil,
    createdAt: String,
    updatedAt: String
  ) {
    self.id = id
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.position = position
    self.schoolId = schoolId
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
    self.responsivenessScore = responsivenessScore
    self.lastContactDate = lastContactDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case email
    case phone
    case position
    case role
    case schoolId = "school_id"
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
    case responsivenessScore = "responsiveness_score"
    case lastContactDate = "last_contact_date"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    firstName = try container.decode(String.self, forKey: .firstName)
    lastName = try container.decode(String.self, forKey: .lastName)
    email = try container.decodeIfPresent(String.self, forKey: .email)
    phone = try container.decodeIfPresent(String.self, forKey: .phone)
    // Database may return "role" (from CoachCreateRequest) or "position" (from CoachUpdateRequest)
    position = try container.decodeIfPresent(String.self, forKey: .position)
      ?? container.decodeIfPresent(String.self, forKey: .role)
    schoolId = try container.decode(String.self, forKey: .schoolId)
    twitterHandle = try container.decodeIfPresent(String.self, forKey: .twitterHandle)
    instagramHandle = try container.decodeIfPresent(String.self, forKey: .instagramHandle)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    responsivenessScore = try container.decodeIfPresent(Double.self, forKey: .responsivenessScore) ?? 0.0
    lastContactDate = try container.decodeIfPresent(String.self, forKey: .lastContactDate)
    createdAt = try container.decode(String.self, forKey: .createdAt)
    updatedAt = try container.decode(String.self, forKey: .updatedAt)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(firstName, forKey: .firstName)
    try container.encode(lastName, forKey: .lastName)
    try container.encodeIfPresent(email, forKey: .email)
    try container.encodeIfPresent(phone, forKey: .phone)
    try container.encodeIfPresent(position, forKey: .position)
    try container.encode(schoolId, forKey: .schoolId)
    try container.encodeIfPresent(twitterHandle, forKey: .twitterHandle)
    try container.encodeIfPresent(instagramHandle, forKey: .instagramHandle)
    try container.encodeIfPresent(notes, forKey: .notes)
    try container.encodeIfPresent(privateNotes, forKey: .privateNotes)
    try container.encode(responsivenessScore, forKey: .responsivenessScore)
    try container.encodeIfPresent(lastContactDate, forKey: .lastContactDate)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
    // role is decoding-only (database may return role or position)
  }

  private static func decodePrivateNotes(from container: KeyedDecodingContainer<CodingKeys>) -> [String: String]? {
    guard let value = try? container.decodeIfPresent(PrivateNotesValue.self, forKey: .privateNotes) else {
      return nil
    }
    return value.toDictionary
  }

  private enum PrivateNotesValue: Decodable {
    case dict([String: String])
    case string(String)

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let dict = try? container.decode([String: String].self) {
        self = .dict(dict)
      } else if let str = try? container.decode(String.self) {
        self = .string(str)
      } else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "private_notes must be dictionary or string"
        )
      }
    }

    var toDictionary: [String: String]? {
      switch self {
      case .dict(let d): return d.isEmpty ? nil : d
      case .string(let s):
        guard !s.isEmpty,
              let data = s.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: String].self, from: data) else {
          return nil
        }
        return parsed
      }
    }
  }

  func privateNote(for userId: String) -> String? {
    privateNotes?[userId]
  }
}
