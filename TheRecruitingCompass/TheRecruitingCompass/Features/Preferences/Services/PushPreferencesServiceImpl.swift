import Foundation
import OSLog
import Supabase

private let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "PushPreferencesService"
)

private struct PushPreferenceRow: Codable {
    let notificationType: String
    let pushEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case notificationType = "notification_type"
        case pushEnabled = "push_enabled"
    }
}

private struct PushPreferenceUpsert: Codable {
    let userId: String
    let notificationType: String
    let pushEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case notificationType = "notification_type"
        case pushEnabled = "push_enabled"
    }
}

final class PushPreferencesServiceImpl: PushPreferencesManaging, Sendable {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager = .shared) {
        self.supabaseManager = supabaseManager
    }

    func fetchPreferences(userId: String) async throws -> [NotificationType: Bool] {
        let rows: [PushPreferenceRow] = try await supabaseManager.client
            .from("notification_preferences")
            .select("notification_type, push_enabled")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let type = NotificationType(rawValue: row.notificationType) else { return nil }
            return (type, row.pushEnabled)
        })
    }

    func updatePreference(userId: String, type: NotificationType, pushEnabled: Bool) async throws {
        let row = PushPreferenceUpsert(userId: userId, notificationType: type.rawValue, pushEnabled: pushEnabled)
        try await supabaseManager.client
            .from("notification_preferences")
            .upsert(row, onConflict: "user_id,notification_type")
            .execute()
        logger.info("Updated push preference: \(type.rawValue) = \(pushEnabled)")
    }

    func seedDefaultPreferences(userId: String) async throws {
        let rows = NotificationType.allCases
            .filter { $0 != .unknown }
            .map { PushPreferenceUpsert(userId: userId, notificationType: $0.rawValue, pushEnabled: true) }
        try await supabaseManager.client
            .from("notification_preferences")
            .upsert(rows, onConflict: "user_id,notification_type", ignoreDuplicates: true)
            .execute()
        logger.info("Seeded default push preferences for user")
    }
}
