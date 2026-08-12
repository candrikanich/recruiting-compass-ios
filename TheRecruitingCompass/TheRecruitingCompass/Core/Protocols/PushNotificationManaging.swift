import Foundation
import UserNotifications

/// Manages APNs registration, device-token persistence, badge count, and notification tap routing.
@MainActor
protocol PushNotificationManaging: AnyObject, Sendable {
  /// Presents the system permission prompt for remote notifications.
  func requestPermission() async
  /// Sends the APNs device token to the backend for the current user.
  func registerDeviceToken(_ token: Data) async
  /// Removes the stored device token from the backend (call on logout or account deletion).
  func deleteDeviceToken() async
  /// Parses a push payload and returns the in-app navigation destination, or `nil` if unrecognised.
  func handleNotificationTap(payload: [AnyHashable: Any]) -> NotificationDestination?
  /// Fetches the unread notification count from the backend and updates the app badge.
  func syncBadgeCount() async
  /// Resets the app badge to zero without a network call.
  func clearBadge()
}

extension Notification.Name {
  /// Posted through `NotificationCenter` whenever the user taps a push notification.
  static let pushNotificationTapped = Notification.Name("com.chrisandrikanich.TheRecruitingCompass.pushTapped")
}
