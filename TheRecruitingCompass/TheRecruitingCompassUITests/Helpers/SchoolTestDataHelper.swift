import Foundation
import Supabase

// MARK: - Type-Safe Data Structures

/// Basic school insert data
private struct SchoolInsert: Encodable {
  let id: String
  let userId: String
  let name: String
  let status: String
  let isFavorite: Bool
  let familyUnitId: String
  let pros: [String]
  let cons: [String]
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name
    case status
    case isFavorite = "is_favorite"
    case familyUnitId = "family_unit_id"
    case pros
    case cons
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

/// Detailed school insert data with optional fields
private struct SchoolDetailInsert: Encodable {
  let id: String
  let userId: String
  let name: String
  let status: String
  let isFavorite: Bool
  let familyUnitId: String
  let pros: [String]
  let cons: [String]
  let createdAt: String
  let updatedAt: String
  let notes: String?
  let location: String?
  let division: String?
  let conference: String?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name
    case status
    case isFavorite = "is_favorite"
    case familyUnitId = "family_unit_id"
    case pros
    case cons
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case notes
    case location
    case division
    case conference
  }
}

/// School status update data
private struct SchoolStatusUpdate: Encodable {
  let status: String
  let statusChangedAt: String
  let updatedAt: String
  let updatedBy: String

  enum CodingKeys: String, CodingKey {
    case status
    case statusChangedAt = "status_changed_at"
    case updatedAt = "updated_at"
    case updatedBy = "updated_by"
  }
}

/// School status history insert data
private struct SchoolStatusHistoryInsert: Encodable {
  let id: String
  let schoolId: String
  let status: String
  let changedBy: String
  let changedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case schoolId = "school_id"
    case status
    case changedBy = "changed_by"
    case changedAt = "changed_at"
  }
}

/// School pros/cons response
private struct SchoolListResponse: Decodable {
  let pros: [String]
  let cons: [String]
}

/// School pros update
private struct SchoolProsUpdate: Encodable {
  let pros: [String]
}

/// School cons update
private struct SchoolConsUpdate: Encodable {
  let cons: [String]
}

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

    let schoolData = SchoolInsert(
      id: schoolId,
      userId: userId,
      name: schoolName,
      status: status,
      isFavorite: isFavorite,
      familyUnitId: familyUnitId,
      pros: [],
      cons: [],
      createdAt: now,
      updatedAt: now
    )

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
  ///   - pros: List of pros
  ///   - cons: List of cons
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
    pros: [String] = [],
    cons: [String] = [],
    location: String? = nil,
    division: String? = nil,
    conference: String? = nil
  ) async throws -> String {
    let schoolId = UUID().uuidString
    let timestamp = Int(Date().timeIntervalSince1970)
    let schoolName = name ?? "Test School \(timestamp)"
    let now = ISO8601DateFormatter().string(from: Date())

    let schoolData = SchoolDetailInsert(
      id: schoolId,
      userId: userId,
      name: schoolName,
      status: status,
      isFavorite: isFavorite,
      familyUnitId: familyUnitId,
      pros: pros,
      cons: cons,
      createdAt: now,
      updatedAt: now,
      notes: notes,
      location: location,
      division: division,
      conference: conference
    )

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
    let statusUpdate = SchoolStatusUpdate(
      status: status,
      statusChangedAt: now,
      updatedAt: now,
      updatedBy: userId
    )

    try await client
      .from("schools")
      .update(statusUpdate)
      .eq("id", value: schoolId)
      .execute()

    // Create status history entry
    let historyEntry = SchoolStatusHistoryInsert(
      id: UUID().uuidString,
      schoolId: schoolId,
      status: status,
      changedBy: userId,
      changedAt: now
    )

    try await client
      .from("school_status_history")
      .insert(historyEntry)
      .execute()
  }

  /// Adds a pro to a school
  func addPro(schoolId: String, pro: String) async throws {
    // Fetch current pros and cons
    let response: SchoolListResponse = try await client
      .from("schools")
      .select("pros, cons")
      .eq("id", value: schoolId)
      .single()
      .execute()
      .value

    var updatedPros = response.pros
    updatedPros.append(pro)

    // Update with new pros list
    let prosUpdate = SchoolProsUpdate(pros: updatedPros)
    try await client
      .from("schools")
      .update(prosUpdate)
      .eq("id", value: schoolId)
      .execute()
  }

  /// Adds a con to a school
  func addCon(schoolId: String, con: String) async throws {
    // Fetch current pros and cons
    let response: SchoolListResponse = try await client
      .from("schools")
      .select("pros, cons")
      .eq("id", value: schoolId)
      .single()
      .execute()
      .value

    var updatedCons = response.cons
    updatedCons.append(con)

    // Update with new cons list
    let consUpdate = SchoolConsUpdate(cons: updatedCons)
    try await client
      .from("schools")
      .update(consUpdate)
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
