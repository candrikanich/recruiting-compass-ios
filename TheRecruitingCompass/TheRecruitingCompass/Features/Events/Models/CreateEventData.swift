import Foundation

struct CreateEventData {
  var type: EventType?
  var name: String = ""
  /// Defaults to today so the form's Start Date picker reflects a real model
  /// value from the start — otherwise the picker shows today while `startDate`
  /// stays nil, silently keeping the Create button disabled.
  var startDate: Date? = Date()
  var endDate: Date?
  var startTime: Date?
  var endTime: Date?
  var checkinTime: Date?
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
