import Foundation

struct CreateEventData {
  var type: EventType?
  var name: String = ""
  var startDate: String = ""
  var endDate: String = ""
  var startTime: String = ""
  var endTime: String = ""
  var checkinTime: String = ""
  var schoolId: String?
  var location: String = ""
  var address: String = ""
  var city: String = ""
  var state: String = ""
  var url: String = ""
  var description: String = ""
  var eventSource: EventSource?
  var cost: String = ""
  var registered: Bool = false
  var attended: Bool = false
  var performanceNotes: String = ""
}

struct CreateEventRequest: Encodable, Sendable {
  let type: String
  let name: String
  let startDate: String
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
  let registered: Bool
  let attended: Bool
  let performanceNotes: String?
  let userId: String

  enum CodingKeys: String, CodingKey {
    case type, name, location, address, city, state, url, description, cost, registered, attended
    case startDate = "start_date"
    case endDate = "end_date"
    case startTime = "start_time"
    case endTime = "end_time"
    case checkinTime = "checkin_time"
    case schoolId = "school_id"
    case eventSource = "event_source"
    case performanceNotes = "performance_notes"
    case userId = "user_id"
  }

  static func from(formData: CreateEventData, userId: String) -> CreateEventRequest {
    CreateEventRequest(
      type: formData.type?.rawValue ?? "",
      name: formData.name.trimmingCharacters(in: .whitespaces),
      startDate: formData.startDate,
      endDate: formData.endDate.isEmpty ? nil : formData.endDate,
      startTime: formData.startTime.isEmpty ? nil : formData.startTime,
      endTime: formData.endTime.isEmpty ? nil : formData.endTime,
      checkinTime: formData.checkinTime.isEmpty ? nil : formData.checkinTime,
      schoolId: formData.schoolId,
      location: formData.location.isEmpty ? nil : formData.location,
      address: formData.address.isEmpty ? nil : formData.address,
      city: formData.city.isEmpty ? nil : formData.city,
      state: formData.state.isEmpty ? nil : formData.state.uppercased(),
      url: formData.url.isEmpty ? nil : formData.url,
      description: formData.description.isEmpty ? nil : formData.description,
      eventSource: formData.eventSource?.rawValue,
      cost: Double(formData.cost),
      registered: formData.registered,
      attended: formData.attended,
      performanceNotes: formData.performanceNotes.isEmpty ? nil : formData.performanceNotes,
      userId: userId
    )
  }
}
