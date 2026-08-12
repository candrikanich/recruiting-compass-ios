import Foundation

/// A lightweight school summary used in event and coach pickers, avoiding a full `School` fetch.
struct SchoolSummary: Codable, Identifiable, Sendable {
  /// Supabase school UUID.
  let id: String
  /// The school's display name.
  let name: String
  /// Optional city/state location string.
  let location: String?
}

/// Service contract for recruiting event CRUD operations, performance metrics, and related entity lookups.
protocol EventsManaging: Sendable {
  /// Creates a new event record and returns the fully populated entity.
  func createEvent(_ request: CreateEventRequest) async throws -> FullEvent
  /// Returns a single event by ID, scoped to the given user.
  func fetchEvent(id: String, userId: String) async throws -> FullEvent
  /// Returns all events belonging to the given user.
  func fetchEvents(userId: String) async throws -> [FullEvent]
  /// Applies updates to an existing event and returns the updated entity.
  func updateEvent(id: String, request: EventUpdateRequest) async throws -> FullEvent
  /// Permanently deletes an event and all associated performance metrics.
  func deleteEvent(id: String) async throws
  /// Returns school summaries for populating school pickers within the event form.
  func fetchSchools(userId: String) async throws -> [SchoolSummary]
  /// Creates a minimal school record inline from the event form.
  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary
  /// Returns coaches associated with a specific school, scoped to the user.
  func fetchCoaches(schoolId: String, userId: String) async throws -> [Coach]
  /// Returns all performance metrics logged for a specific event.
  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric]
  /// Adds a performance metric to an event and returns the persisted entity.
  func createMetric(_ request: CreateMetricRequest) async throws -> PerformanceMetric
  /// Deletes a performance metric by ID.
  func deleteMetric(id: String) async throws
  /// Logs a coach interaction generated during or after an event.
  func createInteraction(_ request: CreateInteractionRequest) async throws
}
