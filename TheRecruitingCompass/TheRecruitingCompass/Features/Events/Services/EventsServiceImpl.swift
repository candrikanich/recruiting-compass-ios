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
    logger.debug("Fetching event: \(id)")
    do {
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
    } catch {
      logger.error("fetchEvent \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchEvents(userId: String) async throws -> [FullEvent] {
    logger.debug("Fetching events for user: \(userId, privacy: .private)")
    do {
      let results: [FullEvent] = try await supabaseManager.client
        .from("events")
        .select()
        .eq("user_id", value: userId)
        .order("start_date", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(results.count) events")
      return results
    } catch {
      logger.error("fetchEvents failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchSchools(userId: String) async throws -> [SchoolSummary] {
    logger.debug("Fetching schools for family unit: \(userId, privacy: .private)")
    do {
      let results: [SchoolSummary] = try await supabaseManager.client
        .from("schools")
        .select("id, name, location")
        .eq("family_unit_id", value: userId)
        .order("name")
        .execute()
        .value
      logger.info("Fetched \(results.count) schools")
      return results
    } catch {
      logger.error("fetchSchools failed: \(error.localizedDescription)")
      throw error
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
    logger.debug("Fetching coaches for school: \(schoolId)")
    do {
      let results: [Coach] = try await supabaseManager.client
        .from("coaches")
        .select("id,first_name,last_name,position,email,phone,school_id,twitter_handle,instagram_handle,notes,last_contact_date,created_at,updated_at")
        .eq("school_id", value: schoolId)
        .execute()
        .value
      logger.info("Fetched \(results.count) coaches")
      return results
    } catch {
      logger.error("fetchCoaches for school \(schoolId) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchMetrics(eventId: String, userId: String) async throws -> [PerformanceMetric] {
    logger.debug("Fetching metrics for event: \(eventId)")
    do {
      let results: [PerformanceMetric] = try await supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("event_id", value: eventId)
        .eq("user_id", value: userId)
        .execute()
        .value
      logger.info("Fetched \(results.count) metrics")
      return results
    } catch {
      logger.error("fetchMetrics for event \(eventId) failed: \(error.localizedDescription)")
      throw error
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
