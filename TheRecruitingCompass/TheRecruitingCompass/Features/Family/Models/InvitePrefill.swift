import Foundation

/// Prefill data returned with invite when role is player and parent entered details.
struct InvitePrefill: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
  let sport: String?
  let position: String?
  let graduationYear: Int?
  /// "yyyy-MM-dd". Only ever populated on the authenticated accept-invite response — the
  /// unauthenticated invite-lookup endpoint deliberately omits player PII including DOB.
  let dateOfBirth: String?

  enum CodingKeys: String, CodingKey {
    case firstName
    case lastName
    case sport
    case position
    case graduationYear
    case dateOfBirth
  }

  init(
    firstName: String,
    lastName: String,
    sport: String? = nil,
    position: String? = nil,
    graduationYear: Int? = nil,
    dateOfBirth: String? = nil
  ) {
    self.firstName = firstName
    self.lastName = lastName
    self.sport = sport
    self.position = position
    self.graduationYear = graduationYear
    self.dateOfBirth = dateOfBirth
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    firstName = try c.decode(String.self, forKey: .firstName)
    lastName = try c.decode(String.self, forKey: .lastName)
    sport = try c.decodeIfPresent(String.self, forKey: .sport)
    position = try c.decodeIfPresent(String.self, forKey: .position)
    graduationYear = try c.decodeIfPresent(Int.self, forKey: .graduationYear)
    dateOfBirth = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(firstName, forKey: .firstName)
    try c.encode(lastName, forKey: .lastName)
    try c.encodeIfPresent(sport, forKey: .sport)
    try c.encodeIfPresent(position, forKey: .position)
    try c.encodeIfPresent(graduationYear, forKey: .graduationYear)
    try c.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
  }
}
