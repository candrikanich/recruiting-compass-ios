import Foundation

protocol PreferenceManaging: Sendable {
  /// Fetch preferences for a category.
  /// - Parameter userId: whose preferences to read. `nil` = the current user. A non-nil value
  ///   targets a family member (e.g. a parent reading the athlete's player-owned prefs); the DB
  ///   RLS policies decide whether the read is permitted.
  /// Returns nil if no preferences exist for the category.
  func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T?

  /// Save preferences for a category.
  /// - Parameter userId: whose row to write. `nil` = the current user. A non-nil value targets a
  ///   family member's row (RLS-gated). Creates a new row if none exists, updates otherwise.
  func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T

  /// Delete preferences for a specific category (current user only)
  func deletePreferences(category: PreferenceCategory) async throws
}

extension PreferenceManaging {
  /// Convenience: read the current user's own preferences.
  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    try await fetchPreferences(category: category, userId: nil)
  }

  /// Convenience: save the current user's own preferences.
  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T {
    try await savePreferences(category: category, userId: nil, data: data)
  }
}
