import Foundation
import UserNotifications

@MainActor
protocol PushNotificationManaging: AnyObject, Sendable {
    func requestPermission() async
    func registerDeviceToken(_ token: Data) async
    func deleteDeviceToken() async
    func handleNotificationTap(payload: [AnyHashable: Any]) -> NotificationDestination?
    func syncBadgeCount() async
    func clearBadge()
}

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("com.chrisandrikanich.TheRecruitingCompass.pushTapped")
}
