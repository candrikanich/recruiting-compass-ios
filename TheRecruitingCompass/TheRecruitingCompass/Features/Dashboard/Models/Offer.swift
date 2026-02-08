import Foundation

struct Offer: Codable, Identifiable, Sendable {
  let id: String
  let schoolId: String
  let amount: Double?
  let type: String?
  let status: String
  let offerDate: String
  let userId: String
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case schoolId = "school_id"
    case amount
    case type
    case status
    case offerDate = "offer_date"
    case userId = "user_id"
    case createdAt = "created_at"
  }
}
