import Foundation

struct OfferDetails: Codable, Sendable {
  let terms: String?
  let startDate: String?
  let endDate: String?
  let conditions: [String]?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case terms
    case startDate = "start_date"
    case endDate = "end_date"
    case conditions, notes
  }
}
