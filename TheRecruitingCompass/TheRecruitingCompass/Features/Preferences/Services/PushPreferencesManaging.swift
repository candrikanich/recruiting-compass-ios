import Foundation

protocol PushPreferencesManaging: Sendable {
    func fetchPreferences(userId: String) async throws -> [NotificationType: Bool]
    func updatePreference(userId: String, type: NotificationType, pushEnabled: Bool) async throws
    func seedDefaultPreferences(userId: String) async throws
}
