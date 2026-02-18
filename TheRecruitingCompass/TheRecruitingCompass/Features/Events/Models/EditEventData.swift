import Foundation

struct EditEventData {
  var name: String = ""
  var type: EventType?
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

  static func from(_ event: FullEvent) -> EditEventData {
    EditEventData(
      name: event.name,
      type: EventType(rawValue: event.type),
      startDate: event.startDate,
      endDate: event.endDate ?? "",
      startTime: event.startTime ?? "",
      endTime: event.endTime ?? "",
      checkinTime: event.checkinTime ?? "",
      schoolId: event.schoolId,
      location: event.location ?? "",
      address: event.address ?? "",
      city: event.city ?? "",
      state: event.state ?? "",
      url: event.url ?? "",
      description: event.description ?? "",
      eventSource: event.eventSource.flatMap { EventSource(rawValue: $0) },
      cost: event.cost.map { String($0) } ?? "",
      registered: event.registered,
      attended: event.attended,
      performanceNotes: event.performanceNotes ?? ""
    )
  }

  func toUpdateRequest() -> EventUpdateRequest {
    EventUpdateRequest(
      name: name.isEmpty ? nil : name,
      type: type?.rawValue,
      startDate: startDate.isEmpty ? nil : startDate,
      endDate: endDate.isEmpty ? nil : endDate,
      startTime: startTime.isEmpty ? nil : startTime,
      endTime: endTime.isEmpty ? nil : endTime,
      checkinTime: checkinTime.isEmpty ? nil : checkinTime,
      schoolId: schoolId,
      location: location.isEmpty ? nil : location,
      address: address.isEmpty ? nil : address,
      city: city.isEmpty ? nil : city,
      state: state.isEmpty ? nil : state,
      url: url.isEmpty ? nil : url,
      description: description.isEmpty ? nil : description,
      eventSource: eventSource?.rawValue,
      cost: Double(cost),
      registered: registered,
      attended: attended,
      performanceNotes: performanceNotes.isEmpty ? nil : performanceNotes,
      coachesPresent: nil
    )
  }
}
