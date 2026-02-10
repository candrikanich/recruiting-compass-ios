import Foundation
import Supabase

/// Helper class for creating and managing test school data via Supabase API
/// Used in E2E tests to set up test scenarios
final class SchoolTestDataHelper {

  // MARK: - Properties

  private let supabaseURL: String
  private let supabaseKey: String
  private lazy var client: SupabaseClient = {
    SupabaseClient(
      supabaseURL: URL(string: supabaseURL)!,
      supabaseKey: supabaseKey
    )
  }()

  // MARK: - Initialization

  init(supabaseURL: String, supabaseKey: String) {
    self.supabaseURL = supabaseURL
    self.supabaseKey = supabaseKey
  }

  // MARK: - School Creation

  /// Creates a test school with minimal required fields
  /// - Parameters:
  ///   - name: School name (defaults to timestamped name)
  ///   - status: Recruiting status (defaults to "interested")
  ///   - isFavorite: Favorite status (defaults to false)
  ///   - userId: User ID (must be provided)
  ///   - familyUnitId: Family unit ID (must be provided)
  /// - Returns: School ID (UUID string)
  @discardableResult
  func createSchool(
    name: String? = nil,
    status: String = "interested",
    isFavorite: Bool = false,
    userId: String,
    familyUnitId: String
  ) async throws -> String {
    let schoolId = UUID().uuidString
    let timestamp = Int(Date().timeIntervalSince1970)
    let schoolName = name ?? "Test School \(timestamp)"
    let now = ISO8601DateFormatter().string(from: Date())

    let schoolData: [String: Any] = [
      "id": schoolId,
      "user_id": userId,
      "name": schoolName,
      "status": status,
      "is_favorite": isFavorite,
      "family_unit_id": familyUnitId,
      "pros": [],
      "cons": [],
      "created_at": now,
      "updated_at": now
    ]

    try await client
      .from("schools")
      .insert(schoolData)
      .execute()

    return schoolId
  }

  /// Creates a school with extended details for testing editing features
  /// - Parameters:
  ///   - name: School name
  ///   - status: Recruiting status
  ///   - isFavorite: Favorite status
  ///   - userId: User ID
  ///   - familyUnitId: Family unit ID
  ///   - notes: Public notes
  ///   - privateNotes: Private notes (keyed by user ID)
  ///   - pros: List of pros
  ///   - cons: List of cons
  ///   - priorityTier: Priority tier (A/B/C/D)
  ///   - location: School location
  ///   - division: Division (D1, D2, D3, NAIA, JUCO)
  ///   - conference: Conference name
  /// - Returns: School ID
  @discardableResult
  func createSchoolWithDetails(
    name: String? = nil,
    status: String = "interested",
    isFavorite: Bool = false,
    userId: String,
    familyUnitId: String,
    notes: String? = nil,
    privateNotes: [String: String]? = nil,
    pros: [String] = [],
    cons: [String] = [],
    priorityTier: String? = nil,
    location: String? = nil,
    division: String? = nil,
    conference: String? = nil
  ) async throws -> String {
    let schoolId = UUID().uuidString
    let timestamp = Int(Date().timeIntervalSince1970)
    let schoolName = name ?? "Test School \(timestamp)"
    let now = ISO8601DateFormatter().string(from: Date())

    var schoolData: [String: Any] = [
      "id": schoolId,
      "user_id": userId,
      "name": schoolName,
      "status": status,
      "is_favorite": isFavorite,
      "family_unit_id": familyUnitId,
      "pros": pros,
      "cons": cons,
      "created_at": now,
      "updated_at": now
    ]

    // Add optional fields if provided
    if let notes = notes {
      schoolData["notes"] = notes
    }
    if let privateNotes = privateNotes {
      schoolData["private_notes"] = privateNotes
    }
    if let priorityTier = priorityTier {
      schoolData["priority_tier"] = priorityTier
    }
    if let location = location {
      schoolData["location"] = location
    }
    if let division = division {
      schoolData["division"] = division
    }
    if let conference = conference {
      schoolData["conference"] = conference
    }

    try await client
      .from("schools")
      .insert(schoolData)
      .execute()

    return schoolId
  }

  // MARK: - School Modification

  /// Updates a school's status and creates a status history entry
  /// - Parameters:
  ///   - schoolId: School ID
  ///   - status: New status
  ///   - userId: User making the change
  func updateSchoolStatus(
    schoolId: String,
    status: String,
    userId: String
  ) async throws {
    let now = ISO8601DateFormatter().string(from: Date())

    // Update school status
    try await client
      .from("schools")
      .update([
        "status": status,
        "status_changed_at": now,
        "updated_at": now,
        "updated_by": userId
      ])
      .eq("id", value: schoolId)
      .execute()

    // Create status history entry
    try await client
      .from("school_status_history")
      .insert([
        "id": UUID().uuidString,
        "school_id": schoolId,
        "status": status,
        "changed_by": userId,
        "changed_at": now
      ])
      .execute()
  }

  /// Adds a pro to a school
  func addPro(schoolId: String, pro: String) async throws {
    // Fetch current pros
    let response = try await client
      .from("schools")
      .select("pros")
      .eq("id", value: schoolId)
      .single()
      .execute()

    let currentPros = (response.value as? [String: Any])?["pros"] as? [String] ?? []
    var updatedPros = currentPros
    updatedPros.append(pro)

    // Update with new pros list
    try await client
      .from("schools")
      .update(["pros": updatedPros])
      .eq("id", value: schoolId)
      .execute()
  }

  /// Adds a con to a school
  func addCon(schoolId: String, con: String) async throws {
    // Fetch current cons
    let response = try await client
      .from("schools")
      .select("cons")
      .eq("id", value: schoolId)
      .single()
      .execute()

    let currentCons = (response.value as? [String: Any])?["cons"] as? [String] ?? []
    var updatedCons = currentCons
    updatedCons.append(con)

    // Update with new cons list
    try await client
      .from("schools")
      .update(["cons": updatedCons])
      .eq("id", value: schoolId)
      .execute()
  }

  // MARK: - School Deletion

  /// Deletes a school by ID
  /// - Parameter schoolId: School ID to delete
  func deleteSchool(schoolId: String) async throws {
    try await client
      .from("schools")
      .delete()
      .eq("id", value: schoolId)
      .execute()
  }

  /// Deletes all schools created by a specific user (cleanup helper)
  /// - Parameter userId: User ID
  func deleteAllSchoolsForUser(userId: String) async throws {
    try await client
      .from("schools")
      .delete()
      .eq("user_id", value: userId)
      .execute()
  }

  // MARK: - Bulk Operations

  /// Creates multiple test schools for list testing
  /// - Parameters:
  ///   - count: Number of schools to create
  ///   - userId: User ID
  ///   - familyUnitId: Family unit ID
  /// - Returns: Array of school IDs
  func createMultipleSchools(
    count: Int,
    userId: String,
    familyUnitId: String
  ) async throws -> [String] {
    var schoolIds: [String] = []

    for i in 0..<count {
      let schoolId = try await createSchool(
        name: "Test School \(i + 1)",
        status: ["interested", "contacted", "visited", "recruited"][i % 4],
        isFavorite: i % 3 == 0,
        userId: userId,
        familyUnitId: familyUnitId
      )
      schoolIds.append(schoolId)
    }

    return schoolIds
  }
}
