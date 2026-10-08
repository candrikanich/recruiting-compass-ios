import Foundation

/// The two columns the Schools list reads from an interaction to mark a school contacted or visited.
/// Fetched instead of full `Interaction` rows, whose notes and attachments grow with the account.
struct SchoolContactSignal: Decodable, Sendable, Equatable {
  let schoolId: String?
  let type: InteractionType

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case type
  }
}
