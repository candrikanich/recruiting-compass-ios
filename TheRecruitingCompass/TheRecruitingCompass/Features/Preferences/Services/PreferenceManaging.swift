import Foundation

protocol PreferenceManaging: Sendable {
  /// Fetch preferences for a specific category
  /// Returns nil if no preferences exist for the category
  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T?

  /// Save preferences for a specific category
  /// Creates new entry if none exists, updates if it does
  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T

  /// Delete preferences for a specific category
  func deletePreferences(category: PreferenceCategory) async throws
}
