import Foundation

/// Insert payload for a school created inline from Create Event.
///
/// `familyUnitId` is optional so an absent family leaves the key out of the JSON; encoding `""`
/// into the uuid column fails with Postgres 22P02.
struct CreateSchoolRequest: Encodable {
  let name: String
  let location: String?
  let userId: String
  let familyUnitId: String?
  let status: String

  enum CodingKeys: String, CodingKey {
    case name, location, status
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
  }
}
