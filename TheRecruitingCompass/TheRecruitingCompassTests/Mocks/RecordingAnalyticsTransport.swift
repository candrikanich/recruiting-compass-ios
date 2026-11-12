@testable import TheRecruitingCompass

final class RecordingTransport: AnalyticsTransport, @unchecked Sendable {
  struct Event { let name: String; let properties: [String: Any] }
  private(set) var events: [Event] = []
  private(set) var identifies: [(userId: String, properties: [String: Any])] = []
  private(set) var resetCount = 0

  func identify(userId: String, properties: [String: Any]) { identifies.append((userId, properties)) }
  func reset() { resetCount += 1 }
  func capture(_ event: String, properties: [String: Any]) { events.append(Event(name: event, properties: properties)) }

  func events(named name: String) -> [Event] { events.filter { $0.name == name } }
}
