import Foundation

/// What a parent staged about an athlete who has not joined yet, as `GET /api/family/pending-athlete` returns it.
/// Only the first name and graduation year leave the server: all the parent's first-run needs.
struct PendingAthlete: Decodable, Equatable, Sendable {
  let athleteFirstName: String?
  let graduationYear: Int?
}

struct PendingAthleteResponse: Decodable, Sendable {
  let pending: PendingAthlete?
}
