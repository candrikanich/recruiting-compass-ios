import Foundation

struct EventUpdateRequest: Encodable, Sendable {
  let name: String?
  let type: String?
  let startDate: String?
  let endDate: String?
  let startTime: String?
  let endTime: String?
  let checkinTime: String?
  let schoolId: String?
  let location: String?
  let address: String?
  let city: String?
  let state: String?
  let url: String?
  let description: String?
  let eventSource: String?
  let cost: Double?
  let registered: Bool?
  let attended: Bool?
  let performanceNotes: String?
  let coachesPresent: [String]?

  enum CodingKeys: String, CodingKey {
    case name, type, location, address, city, state, url, description, cost, registered, attended
    case startDate = "start_date"
    case endDate = "end_date"
    case startTime = "start_time"
    case endTime = "end_time"
    case checkinTime = "checkin_time"
    case schoolId = "school_id"
    case eventSource = "event_source"
    case performanceNotes = "performance_notes"
    case coachesPresent = "coaches_present"
  }
}
