import Foundation

/// Prefill data returned with invite when role is player and parent entered details.
struct InvitePrefill: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
  let sport: String?
  let position: String?
  let graduationYear: Int?

  enum CodingKeys: String, CodingKey {
    case firstName
    case lastName
    case sport
    case position
    case graduationYear
  }

  init(firstName: String, lastName: String, sport: String? = nil, position: String? = nil, graduationYear: Int? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.sport = sport
    self.position = position
    self.graduationYear = graduationYear
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    firstName = try c.decode(String.self, forKey: .firstName)
    lastName = try c.decode(String.self, forKey: .lastName)
    sport = try c.decodeIfPresent(String.self, forKey: .sport)
    position = try c.decodeIfPresent(String.self, forKey: .position)
    graduationYear = try c.decodeIfPresent(Int.self, forKey: .graduationYear)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(firstName, forKey: .firstName)
    try c.encode(lastName, forKey: .lastName)
    try c.encodeIfPresent(sport, forKey: .sport)
    try c.encodeIfPresent(position, forKey: .position)
    try c.encodeIfPresent(graduationYear, forKey: .graduationYear)
  }
}
