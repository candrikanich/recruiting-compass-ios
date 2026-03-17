import Foundation
@testable import TheRecruitingCompass

// @unchecked Sendable required: protocol is Sendable but test mock uses mutable state
final class MockPushNotificationManager: PushNotificationManaging, @unchecked Sendable {
    var requestPermissionCalled = false
    var registeredTokenData: Data?
    var deleteDeviceTokenCalled = false
    var syncBadgeCountCalled = false
    var clearBadgeCalled = false
    var tapPayload: [AnyHashable: Any]?
    var tapResult: NotificationDestination?

    func requestPermission() async { requestPermissionCalled = true }
    func registerDeviceToken(_ token: Data) async { registeredTokenData = token }
    func deleteDeviceToken() async { deleteDeviceTokenCalled = true }
    func syncBadgeCount() async { syncBadgeCountCalled = true }
    func clearBadge() { clearBadgeCalled = true }
    func handleNotificationTap(payload: [AnyHashable: Any]) -> NotificationDestination? {
        tapPayload = payload
        return tapResult
    }
}
