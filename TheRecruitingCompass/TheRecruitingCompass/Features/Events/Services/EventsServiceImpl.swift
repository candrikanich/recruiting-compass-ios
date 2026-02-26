import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EventsService"
)

final class EventsServiceImpl: EventsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func createEvent(_ request: CreateEventRequest) async throws -> FullEvent {
    logger.debug("Creating event: \(request.name)")

    let result: FullEvent = try await supabaseManager.client
      .from("events")
      .insert(request)
      .select()
      .single()
      .execute()
      .value

    logger.info("Event created: \(result.id)")
    return result
  }

  func fetchEvent(id: String, userId: String) async throws -> FullEvent {
    logger.debug("Fetching event: \(id)")

    let result: FullEvent = try await supabaseManager.client
      .from("events")
      .select()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .single()
      .execute()
      .value

    logger.info("Fetched event: \(result.id)")
    return result
  }

  func fetchEvents(userId: String) async throws -> [FullEvent] {
    logger.debug("Fetching events for user: \(userId)")

    let results: [FullEvent] = try await supabaseManager.client
      .from("events")
      .select()
      .eq("user_id", value: userId)
      .order("start_date", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(results.count) events")
    return results
  }

  func fetchSchools(userId: String) async throws -> [SchoolSummary] {
    logger.debug("Fetching schools for family unit: \(userId)")

    let results: [SchoolSummary] = try await supabaseManager.client
      .from("schools")
      .select("id, name, location")
      .eq("family_unit_id", value: userId)
      .order("name")
      .execute()
      .value

    logger.info("Fetched \(results.count) schools")
    return results
  }

  func updateEvent(id: String, request: EventUpdateRequest) async throws -> FullEvent {
    logger.debug("Updating event: \(id)")

    let result: FullEvent = try await supabaseManager.client
      .from("events")
      .update(request)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Event updated: \(result.id)")
    return result
  }

  func deleteEvent(id: String) async throws {
    logger.debug("Deleting event: \(id)")

    try await supabaseManager.client
      .from("events")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Event deleted: \(id)")
  }

  func fetchCoaches(schoolId: String, userId: String) async throws -> [Coach] {
    logger.debug("Fetching coaches for school: \(schoolId)")

    let results: [Coach] = try await supabaseManager.client
      .from("coaches")
      .select("id,first_name,last_name,position,email,phone,school_id,twitter_handle,instagram_handle,notes,private_notes,responsiveness_score,last_contact_date,created_at,updated_at")
      .eq("school_id", value: schoolId)
      .execute()
      .value

    logger.info("Fetched \(results.count) coaches")
    return results
  }

  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric] {
    logger.debug("Fetching metrics for event: \(eventId)")

    let results: [PerformanceMetric] = try await supabaseManager.client
      .from("performance_metrics")
      .select()
      .eq("event_id", value: eventId)
      .eq("user_id", value: userId)
      .execute()
      .value

    logger.info("Fetched \(results.count) metrics")
    return results
  }

  func createMetric(_ request: CreateMetricRequest) async throws -> PerformanceMetric {
    logger.debug("Creating metric: \(request.metricType)")

    let result: PerformanceMetric = try await supabaseManager.client
      .from("performance_metrics")
      .insert(request)
      .select()
      .single()
      .execute()
      .value

    logger.info("Metric created: \(result.id)")
    return result
  }

  func deleteMetric(id: String) async throws {
    logger.debug("Deleting metric: \(id)")

    try await supabaseManager.client
      .from("performance_metrics")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Metric deleted: \(id)")
  }

  func createInteraction(_ request: CreateInteractionRequest) async throws {
    logger.debug("Creating interaction for event: \(request.eventId)")

    try await supabaseManager.client
      .from("interactions")
      .insert(request)
      .execute()

    logger.info("Interaction created for event: \(request.eventId)")
  }

  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary {
    logger.debug("Creating school: \(name)")

    struct CreateSchoolRequest: Encodable {
      let name: String
      let location: String?
      let userId: String

      enum CodingKeys: String, CodingKey {
        case name, location
        case userId = "user_id"
      }
    }

    let request = CreateSchoolRequest(name: name, location: location, userId: userId)

    let result: SchoolSummary = try await supabaseManager.client
      .from("schools")
      .insert(request)
      .select("id, name, location")
      .single()
      .execute()
      .value

    logger.info("School created: \(result.id)")
    return result
  }
}
