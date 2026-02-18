import Foundation

struct SchoolSummary: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let location: String?
}

protocol EventsManaging: Sendable {
  func createEvent(_ request: CreateEventRequest) async throws -> FullEvent
  func fetchEvent(id: String) async throws -> FullEvent
  func fetchEvents(userId: String) async throws -> [FullEvent]
  func fetchSchools(userId: String) async throws -> [SchoolSummary]
  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary
}
