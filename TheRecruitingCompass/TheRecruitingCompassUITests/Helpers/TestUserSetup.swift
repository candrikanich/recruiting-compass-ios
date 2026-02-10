import Foundation
import Supabase

/// Complete test user information including IDs needed for test data creation
struct TestUser {
  let id: String
  let email: String
  let password: String
  let fullName: String
  let role: String
  let familyUnitId: String
}

/// Helper class for creating and managing test users via Supabase API
/// Creates users with proper family unit setup for E2E testing
final class TestUserSetup {

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

  // MARK: - Test User Creation

  /// Creates a test parent user with a new family unit
  /// - Returns: TestUser with user ID and family unit ID
  func createTestParent() async throws -> TestUser {
    let timestamp = Int(Date().timeIntervalSince1970)
    let email = "testparent+\(timestamp)@example.com"
    let password = "StrongPass1!"
    let fullName = "Test Parent \(timestamp)"

    // Create user via Supabase Auth
    let authResponse = try await client.auth.signUp(
      email: email,
      password: password,
      data: [
        "full_name": .string(fullName),
        "role": .string("parent")
      ]
    )

    let userId = authResponse.user.id.uuidString

    // Create family unit for parent
    let familyUnitId = UUID().uuidString
    let now = ISO8601DateFormatter().string(from: Date())

    let familyData: [String: Any] = [
      "id": familyUnitId,
      "created_by": userId,
      "family_code": "FAM-\(timestamp)",
      "created_at": now,
      "updated_at": now
    ]

    try await client
      .from("family_units")
      .insert(familyData)
      .execute()

    // Link user to family unit
    try await client
      .from("users")
      .update(["family_unit_id": familyUnitId])
      .eq("id", value: userId)
      .execute()

    return TestUser(
      id: userId,
      email: email,
      password: password,
      fullName: fullName,
      role: "parent",
      familyUnitId: familyUnitId
    )
  }

  /// Creates a test student user linked to a parent's family
  /// - Parameter parentFamilyCode: Family code to join
  /// - Returns: TestUser with user ID and family unit ID
  func createTestStudent(parentFamilyCode: String) async throws -> TestUser {
    let timestamp = Int(Date().timeIntervalSince1970)
    let email = "teststudent+\(timestamp)@example.com"
    let password = "StrongPass1!"
    let fullName = "Test Student \(timestamp)"

    // Create user via Supabase Auth
    let authResponse = try await client.auth.signUp(
      email: email,
      password: password,
      data: [
        "full_name": .string(fullName),
        "role": .string("student"),
        "family_code": .string(parentFamilyCode)
      ]
    )

    let userId = authResponse.user.id.uuidString

    // Get family unit ID from family code
    let familyResponse = try await client
      .from("family_units")
      .select("id")
      .eq("family_code", value: parentFamilyCode)
      .single()
      .execute()

    guard let familyData = familyResponse.value as? [String: Any],
          let familyUnitId = familyData["id"] as? String else {
      throw TestSetupError.familyNotFound
    }

    // Link user to family unit
    try await client
      .from("users")
      .update(["family_unit_id": familyUnitId])
      .eq("id", value: userId)
      .execute()

    return TestUser(
      id: userId,
      email: email,
      password: password,
      fullName: fullName,
      role: "student",
      familyUnitId: familyUnitId
    )
  }

  // MARK: - User Lookup

  /// Gets user information by email (for already-created test users)
  /// - Parameter email: User email
  /// - Returns: TestUser if found
  func getUserByEmail(_ email: String) async throws -> TestUser? {
    // Sign in to get user session
    let authResponse = try await client.auth.signIn(
      email: email,
      password: "StrongPass1!" // Assuming standard test password
    )

    let userId = authResponse.user.id.uuidString

    // Get user data from database
    let userResponse = try await client
      .from("users")
      .select("id, email, full_name, role, family_unit_id")
      .eq("id", value: userId)
      .single()
      .execute()

    guard let userData = userResponse.value as? [String: Any],
          let familyUnitId = userData["family_unit_id"] as? String,
          let fullName = userData["full_name"] as? String,
          let role = userData["role"] as? String else {
      return nil
    }

    return TestUser(
      id: userId,
      email: email,
      password: "StrongPass1!",
      fullName: fullName,
      role: role,
      familyUnitId: familyUnitId
    )
  }

  // MARK: - Cleanup

  /// Deletes a test user and their family unit
  /// - Parameter userId: User ID to delete
  func deleteTestUser(userId: String) async throws {
    // Get family unit ID
    let userResponse = try await client
      .from("users")
      .select("family_unit_id")
      .eq("id", value: userId)
      .single()
      .execute()

    if let userData = userResponse.value as? [String: Any],
       let familyUnitId = userData["family_unit_id"] as? String {
      // Delete family unit (cascade will delete user)
      try await client
        .from("family_units")
        .delete()
        .eq("id", value: familyUnitId)
        .execute()
    }

    // Delete auth user
    // Note: This requires admin privileges, may need to use service role key
    // For now, we'll just delete from users table
    try await client
      .from("users")
      .delete()
      .eq("id", value: userId)
      .execute()
  }

  /// Deletes all test users created in the last hour (cleanup helper)
  func deleteRecentTestUsers() async throws {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let timestamp = ISO8601DateFormatter().string(from: oneHourAgo)

    // Find test users by email pattern
    let usersResponse = try await client
      .from("users")
      .select("id")
      .like("email", pattern: "%testparent%")
      .or("email.like.%teststudent%")
      .gte("created_at", value: timestamp)
      .execute()

    if let usersData = usersResponse.value as? [[String: Any]] {
      for userData in usersData {
        if let userId = userData["id"] as? String {
          try? await deleteTestUser(userId: userId)
        }
      }
    }
  }
}

// MARK: - Errors

enum TestSetupError: LocalizedError {
  case familyNotFound
  case userCreationFailed
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .familyNotFound:
      return "Family unit not found for the provided family code"
    case .userCreationFailed:
      return "Failed to create test user"
    case .invalidResponse:
      return "Invalid response from Supabase API"
    }
  }
}
