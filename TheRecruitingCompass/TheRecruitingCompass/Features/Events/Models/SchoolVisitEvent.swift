import Foundation

/// An official or unofficial visit event, reduced to what the Schools list needs to mark a school visited.
struct SchoolVisitEvent: Decodable, Sendable, Equatable {
  let schoolId: String?
  let startDate: String

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case startDate = "start_date"
  }
}
