import Foundation

/// Parent-entered player info stored on family_units (pending_player_details) or sent with invite.
struct PendingPlayerDetails: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
  let sport: String?
  let position: String?
  let graduationYear: Int?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case sport
    case position
    case graduationYear = "graduation_year"
  }
}
