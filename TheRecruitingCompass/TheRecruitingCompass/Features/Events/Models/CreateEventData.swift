import Foundation

struct CreateEventData {
  var type: EventType?
  var name: String = ""
  var startDate: Date?
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
