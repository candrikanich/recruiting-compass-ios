import Foundation

struct FullEvent: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let type: String
  let schoolId: String?
  let location: String?
  let address: String?
  let city: String?
  let state: String?
  let startDate: String
  let startTime: String?
  let endDate: String?
  let endTime: String?
  let checkinTime: String?
  let url: String?
  let description: String?
  let eventSource: String?
  let cost: Double?
  let registered: Bool
  let attended: Bool
  let performanceNotes: String?
  let userId: String
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id, name, type, location, address, city, state, url, description, cost, registered, attended
    case schoolId = "school_id"
    case startDate = "start_date"
    case startTime = "start_time"
    case endDate = "end_date"
    case endTime = "end_time"
    case checkinTime = "checkin_time"
    case eventSource = "event_source"
    case performanceNotes = "performance_notes"
    case userId = "user_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
