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
    do {
      let result: FullEvent = try await supabaseManager.client
        .from("events")
        .insert(request)
        .select()
        .single()
        .execute()
        .value
      logger.info("Event created: \(result.id)")
      return result
    } catch {
      logger.error("createEvent failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchEvent(id: String, userId: String) async throws -> FullEvent {
    try await logger.fetchOne("event \(id)") {
      try await supabaseManager.client
        .from("events")
        .select()
        .eq("id", value: id)
        .eq("user_id", value: userId)
        .single()
        .execute()
        .value
    }
  }

  func fetchEvents(userId: String) async throws -> [FullEvent] {
    try await logger.fetch("events") {
      try await supabaseManager.client
        .from("events")
        .select()
        .eq("user_id", value: userId)
        .order("start_date", ascending: false)
        .execute()
        .value
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [SchoolSummary] {
    try await logger.fetch("schools") {
      try await supabaseManager.client
        .from("schools")
        .select("id, name, location")
        .eq("family_unit_id", value: familyUnitId)
        .order("name")
        .execute()
        .value
    }
  }

  func updateEvent(id: String, request: EventUpdateRequest) async throws -> FullEvent {
    logger.debug("Updating event: \(id)")
    do {
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
    } catch {
      logger.error("updateEvent \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteEvent(id: String) async throws {
    logger.debug("Deleting event: \(id)")
    do {
      try await supabaseManager.client
        .from("events")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Event deleted: \(id)")
    } catch {
      logger.error("deleteEvent \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchCoaches(schoolId: String, userId: String) async throws -> [Coach] {
    try await logger.fetch("coaches") {
      try await supabaseManager.client
        .from("coaches")
        .select("id,first_name,last_name,position,email,phone,school_id,twitter_handle,instagram_handle,notes,last_contact_date,created_at,updated_at")
        .eq("school_id", value: schoolId)
        .execute()
        .value
    }
  }

  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric] {
    try await logger.fetch("metrics") {
      try await supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("event_id", value: eventId)
        .eq("user_id", value: userId)
        .execute()
        .value
    }
  }

  func createMetric(_ request: CreateMetricRequest) async throws -> PerformanceMetric {
    logger.debug("Creating metric: \(request.metricType)")
    do {
      let result: PerformanceMetric = try await supabaseManager.client
        .from("performance_metrics")
        .insert(request)
        .select()
        .single()
        .execute()
        .value
      logger.info("Metric created: \(result.id)")
      return result
    } catch {
      logger.error("createMetric failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteMetric(id: String) async throws {
    logger.debug("Deleting metric: \(id)")
    do {
      try await supabaseManager.client
        .from("performance_metrics")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Metric deleted: \(id)")
    } catch {
      logger.error("deleteMetric \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func createInteraction(_ request: CreateInteractionRequest) async throws {
    logger.debug("Creating interaction for event: \(request.eventId)")
    do {
      try await supabaseManager.client
        .from("interactions")
        .insert(request)
        .execute()
      logger.info("Interaction created for event: \(request.eventId)")
    } catch {
      logger.error("createInteraction failed: \(error.localizedDescription)")
      throw error
    }
  }

  func createSchool(name: String, location: String?, userId: String, familyUnitId: String) async throws -> SchoolSummary {
    logger.debug("Creating school: \(name)")

    struct CreateSchoolRequest: Encodable {
      let name: String
      let location: String?
      let userId: String
      let familyUnitId: String
      let status: String

      enum CodingKeys: String, CodingKey {
        case name, location, status
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
      }
    }

    let request = CreateSchoolRequest(
      name: name,
      location: location,
      userId: userId,
      familyUnitId: familyUnitId,
      status: SchoolStatus.researching.rawValue
    )
    do {
      let result: SchoolSummary = try await supabaseManager.client
        .from("schools")
        .insert(request)
        .select("id, name, location")
        .single()
        .execute()
        .value
      logger.info("School created: \(result.id)")
      return result
    } catch {
      logger.error("createSchool failed: \(error.localizedDescription)")
      throw error
    }
  }
}
