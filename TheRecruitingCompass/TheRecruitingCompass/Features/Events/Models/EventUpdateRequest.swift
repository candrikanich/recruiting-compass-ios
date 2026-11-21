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
  /// The edit form always owns all three times: send nil as JSON null so clearing a time reaches the database.
  /// Partial updates (attended, coaches) leave this false and never touch the times.
  let writesTimes: Bool

  init(
    name: String? = nil,
    type: String? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    startTime: String? = nil,
    endTime: String? = nil,
    checkinTime: String? = nil,
    schoolId: String? = nil,
    location: String? = nil,
    address: String? = nil,
    city: String? = nil,
    state: String? = nil,
    url: String? = nil,
    description: String? = nil,
    eventSource: String? = nil,
    cost: Double? = nil,
    registered: Bool? = nil,
    attended: Bool? = nil,
    performanceNotes: String? = nil,
    coachesPresent: [String]? = nil,
    writesTimes: Bool = false
  ) {
    self.name = name
    self.type = type
    self.startDate = startDate
    self.endDate = endDate
    self.startTime = startTime
    self.endTime = endTime
    self.checkinTime = checkinTime
    self.schoolId = schoolId
    self.location = location
    self.address = address
    self.city = city
    self.state = state
    self.url = url
    self.description = description
    self.eventSource = eventSource
    self.cost = cost
    self.registered = registered
    self.attended = attended
    self.performanceNotes = performanceNotes
    self.coachesPresent = coachesPresent
    self.writesTimes = writesTimes
  }

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

extension EventUpdateRequest {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(startDate, forKey: .startDate)
    try container.encodeIfPresent(endDate, forKey: .endDate)
    try encodeTime(startTime, forKey: .startTime, in: &container)
    try encodeTime(endTime, forKey: .endTime, in: &container)
    try encodeTime(checkinTime, forKey: .checkinTime, in: &container)
    try container.encodeIfPresent(schoolId, forKey: .schoolId)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encodeIfPresent(address, forKey: .address)
    try container.encodeIfPresent(city, forKey: .city)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(eventSource, forKey: .eventSource)
    try container.encodeIfPresent(cost, forKey: .cost)
    try container.encodeIfPresent(registered, forKey: .registered)
    try container.encodeIfPresent(attended, forKey: .attended)
    try container.encodeIfPresent(performanceNotes, forKey: .performanceNotes)
    try container.encodeIfPresent(coachesPresent, forKey: .coachesPresent)
  }

  private func encodeTime(
    _ value: String?, forKey key: CodingKeys, in container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    if writesTimes {
      try container.encode(value, forKey: key)
    } else {
      try container.encodeIfPresent(value, forKey: key)
    }
  }
}
