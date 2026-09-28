import Foundation
import Supabase

protocol AppVersionPolicyFetching: Sendable {
  func fetchPolicy() async throws -> AppVersionPolicy
}

final class AppVersionPolicyService: AppVersionPolicyFetching, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  /// RPC rather than a table read so logged-out users are covered without granting anon SELECT on app_config.
  func fetchPolicy() async throws -> AppVersionPolicy {
    let rows: [AppVersionPolicy] = try await supabaseManager.client
      .rpc("get_ios_version_policy")
      .execute()
      .value
    return rows.first ?? AppVersionPolicy(minimumVersion: nil, recommendedVersion: nil)
  }
}
