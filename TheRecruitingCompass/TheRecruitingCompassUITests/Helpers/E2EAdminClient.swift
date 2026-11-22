import Foundation
import Supabase

/// Reads database state with the service-role key so a test asserts what was written, not only what the UI shows.
///
/// The key reaches the test runner as `TEST_RUNNER_E2E_SUPABASE_SERVICE_ROLE_KEY` (set by
/// `scripts/e2e/nightly-local.sh` from the throwaway stack). It is never defaulted, and the client refuses any URL
/// that is not this Mac's loopback, so a service-role key can never be sent to QA or production.
final class E2EAdminClient {
  enum SetupError: Error, CustomStringConvertible {
    case missingServiceRoleKey
    case notLocal(String)
    case missingRow(String)

    var description: String {
      switch self {
      case .missingServiceRoleKey:
        return "E2E_SUPABASE_SERVICE_ROLE_KEY is not set: run through scripts/e2e/nightly-local.sh"
      case .notLocal(let url):
        return "Refusing to use the service-role key against \(url): E2E admin access is local-stack only"
      case .missingRow(let what):
        return "Expected a database row but found none: \(what)"
      }
    }
  }

  struct SchoolRow: Decodable, Equatable {
    let name: String
    let isFavorite: Bool?

    enum CodingKeys: String, CodingKey {
      case name
      case isFavorite = "is_favorite"
    }
  }

  private struct IdRow: Decodable { let id: String }
  private struct MemberRow: Decodable {
    let familyUnitId: String
    let role: String

    enum CodingKeys: String, CodingKey {
      case familyUnitId = "family_unit_id"
      case role
    }
  }
  private struct MilestoneData: Decodable {
    let onboardingComplete: Bool?

    enum CodingKeys: String, CodingKey { case onboardingComplete = "onboarding_complete" }
  }
  private struct MilestoneRow: Decodable {
    let phaseMilestoneData: MilestoneData?

    enum CodingKeys: String, CodingKey { case phaseMilestoneData = "phase_milestone_data" }
  }

  private let client: SupabaseClient

  init() throws {
    let url = E2ETestEnvironment.supabaseURL
    guard let host = URL(string: url)?.host, ["127.0.0.1", "localhost"].contains(host) else {
      throw SetupError.notLocal(url)
    }
    let key = ProcessInfo.processInfo.environment["E2E_SUPABASE_SERVICE_ROLE_KEY"] ?? ""
    guard !key.isEmpty else { throw SetupError.missingServiceRoleKey }
    guard let supabaseURL = URL(string: url) else { throw SetupError.notLocal(url) }
    client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
  }

  func userId(email: String) async throws -> String {
    let rows: [IdRow] = try await client.from("users").select("id").eq("email", value: email).execute().value
    guard let row = rows.first else { throw SetupError.missingRow("users.email = \(email)") }
    return row.id
  }

  func familyUnitId(userId: String) async throws -> String {
    let rows: [MemberRow] = try await client
      .from("family_members").select("family_unit_id, role").eq("user_id", value: userId).execute().value
    guard let row = rows.first else { throw SetupError.missingRow("family_members.user_id = \(userId)") }
    return row.familyUnitId
  }

  func memberships(userId: String) async throws -> [(familyUnitId: String, role: String)] {
    let rows: [MemberRow] = try await client
      .from("family_members").select("family_unit_id, role").eq("user_id", value: userId).execute().value
    return rows.map { ($0.familyUnitId, $0.role) }
  }

  func schools(familyUnitId: String) async throws -> [SchoolRow] {
    try await client
      .from("schools").select("name, is_favorite").eq("family_unit_id", value: familyUnitId).execute().value
  }

  func onboardingComplete(userId: String) async throws -> Bool {
    let rows: [MilestoneRow] = try await client
      .from("users").select("phase_milestone_data").eq("id", value: userId).execute().value
    return rows.first?.phaseMilestoneData?.onboardingComplete ?? false
  }
}
