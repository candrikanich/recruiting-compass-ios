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
  func updateEvent(id: String, request: EventUpdateRequest) async throws -> FullEvent
  func deleteEvent(id: String) async throws
  func fetchSchools(userId: String) async throws -> [SchoolSummary]
  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary
  func fetchCoaches(schoolId: String, userId: String) async throws -> [Coach]
  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric]
  func createMetric(_ request: CreateMetricRequest) async throws -> PerformanceMetric
  func deleteMetric(id: String) async throws
  func createInteraction(_ request: CreateInteractionRequest) async throws
}
