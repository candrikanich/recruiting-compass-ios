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

  func fetchEvent(id: String) async throws -> FullEvent {
    logger.debug("Fetching event: \(id)")

    let result: FullEvent = try await supabaseManager.client
      .from("events")
      .select()
      .eq("id", value: id)
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
    logger.debug("Fetching schools for user: \(userId)")

    let results: [SchoolSummary] = try await supabaseManager.client
      .from("schools")
      .select("id, name, location")
      .eq("user_id", value: userId)
      .order("name")
      .execute()
      .value

    logger.info("Fetched \(results.count) schools")
    return results
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

  func deleteEvent(id: String) async throws {
    let client = SupabaseManager.shared.client
    try await client.from("events").delete().eq("id", value: id).execute()
  }
}
