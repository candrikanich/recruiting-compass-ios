import Foundation
import OSLog
import UserNotifications
import UIKit
import Supabase

private let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "PushNotificationManager"
)

private struct DeviceTokenRow: Encodable {
    let userId: String
    let token: String
    let platform: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"; case token; case platform
    }
}

@MainActor
final class PushNotificationManager: NSObject, PushNotificationManaging {
    nonisolated deinit {}
    static let shared = PushNotificationManager()

    private(set) var currentTokenString: String?
    private let supabaseManager: SupabaseManager
    private let authManager: any AuthManaging

    /// Dependencies default inside the initializer body so default-argument evaluation
    /// does not run in a nonisolated context (Swift 6 / strict concurrency).
    init(supabaseManager: SupabaseManager? = nil, authManager: (any AuthManaging)? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        self.authManager = authManager ?? AuthManager.shared
    }

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Push permission granted: \(granted)")
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        } catch {
            logger.error("Push permission request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Token

    func registerDeviceToken(_ token: Data) async {
        let hex = token.map { String(format: "%02.2hhx", $0) }.joined()
        guard let userId = authManager.user?.id else {
            logger.warning("No authenticated user — skipping device token registration")
            return
        }
        currentTokenString = hex
        do {
            try await supabaseManager.client
                .from("device_tokens")
                .upsert(
                    DeviceTokenRow(userId: userId, token: hex, platform: "ios"),
                    onConflict: "user_id,token"
                )
                .execute()
            logger.info("Device token upserted")
        } catch {
            logger.error("Device token upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteDeviceToken() async {
        guard let token = currentTokenString,
              let userId = authManager.user?.id else { return }
        // Clear in-memory token immediately so callers see nil even if the Supabase call fails.
        // If the deletion fails, the orphaned row is harmless — the next login for the same user
        // on this device will upsert the same token, and the row is keyed on (user_id, token).
        currentTokenString = nil
        do {
            try await supabaseManager.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()
            logger.info("Device token deleted")
        } catch {
            logger.error("Device token deletion failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Badge

    func syncBadgeCount() async {
        guard let userId = authManager.user?.id else { return }
        do {
            let response = try await supabaseManager.client
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .is("read_at", value: nil)
                .execute()
            let count = response.count ?? 0
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                logger.error("Badge sync setBadgeCount failed: \(error.localizedDescription)")
            }
        } catch {
            logger.error("Badge sync failed: \(error.localizedDescription)")
        }
    }

    func clearBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                logger.error("Clear badge failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Navigation

    func handleNotificationTap(payload: [AnyHashable: Any]) -> NotificationDestination? {
        NotificationDestinationParser.destination(fromPayload: payload)
    }

    // MARK: - Testing

    #if DEBUG
    var currentTokenStringForTesting: String? { currentTokenString }
    #endif
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            if let destination = NotificationDestinationParser.destination(fromPayload: userInfo) {
                NotificationCenter.default.post(
                    name: .pushNotificationTapped,
                    object: nil,
                    userInfo: ["destination": destination]
                )
            }
        }
        completionHandler()
    }
}
