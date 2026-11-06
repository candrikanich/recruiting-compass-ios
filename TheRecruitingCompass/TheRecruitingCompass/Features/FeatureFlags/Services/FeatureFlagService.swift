import Foundation
import Supabase

protocol FeatureFlagFetching: Sendable {
  func fetchDisabledFeatureKeys() async throws -> [String]
}

final class FeatureFlagService: FeatureFlagFetching, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  /// RPC rather than a table read so logged-out users are covered without granting anon SELECT on app_config.
  func fetchDisabledFeatureKeys() async throws -> [String] {
    try await supabaseManager.client
      .rpc("get_ios_disabled_features")
      .execute()
      .value
  }
}
