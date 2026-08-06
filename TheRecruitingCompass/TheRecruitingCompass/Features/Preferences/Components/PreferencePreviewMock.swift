import Foundation

/// Generic mock preference service for SwiftUI previews
/// This mock can be used in any preference view preview by providing a default value
///
/// Example usage:
/// ```swift
/// #Preview {
///   NavigationStack {
///     NotificationPreferencesView(
///       preferenceService: PreferencePreviewMock(defaultValue: NotificationSettings.default)
///     )
///   }
/// }
/// ```
final class PreferencePreviewMock<T: Codable>: PreferenceManaging {
  nonisolated(unsafe) private let defaultValue: T?

  init(defaultValue: T? = nil) {
    self.defaultValue = defaultValue
  }

  func fetchPreferences<U: Codable>(category: PreferenceCategory) async throws -> U? {
    return defaultValue as? U
  }

  func savePreferences<U: Codable>(category: PreferenceCategory, data: U) async throws -> U {
    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {
    // No-op for previews
  }
}
