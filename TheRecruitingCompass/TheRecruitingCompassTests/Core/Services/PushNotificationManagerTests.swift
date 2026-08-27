import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("PushNotificationManager", .serialized)
@MainActor
struct PushNotificationManagerTests {

    @Test func registerDeviceTokenFormatsHexString() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = makeTestUser(id: "user-abc")
        authManager.user = authManager.mockUserToReturn
        let manager = PushNotificationManager(authManager: authManager, isRunningOnSimulator: false)

        let tokenData = Data([0xAB, 0xCD, 0xEF])
        await manager.registerDeviceToken(tokenData)

        #expect(manager.currentTokenStringForTesting == "abcdef")
    }

    @Test func registerDeviceTokenSkipsOnSimulator() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = makeTestUser(id: "user-abc")
        authManager.user = authManager.mockUserToReturn
        let manager = PushNotificationManager(authManager: authManager, isRunningOnSimulator: true)

        await manager.registerDeviceToken(Data([0xAB, 0xCD, 0xEF]))

        #expect(manager.currentTokenStringForTesting == nil)
    }

    @Test func registerDeviceTokenNoOpWhenNoUser() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = nil
        authManager.user = nil
        let manager = PushNotificationManager(authManager: authManager)

        await manager.registerDeviceToken(Data([0x01, 0x02]))

        #expect(manager.currentTokenStringForTesting == nil)
    }

    @Test func deleteDeviceTokenClearsCurrentToken() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = makeTestUser(id: "user-abc")
        authManager.user = authManager.mockUserToReturn
        let manager = PushNotificationManager(authManager: authManager, isRunningOnSimulator: false)
        await manager.registerDeviceToken(Data([0xAA]))

        await manager.deleteDeviceToken()

        #expect(manager.currentTokenStringForTesting == nil)
    }

    @Test func clearBadgeCallsUNCenter() async {
        let manager = PushNotificationManager(authManager: MockAuthManager())
        // Should not throw — exercise the path
        manager.clearBadge()
    }

    @Test func handleTapDelegatesToParser() async {
        let manager = PushNotificationManager(authManager: MockAuthManager())
        let payload: [AnyHashable: Any] = ["related_entity_type": "school", "related_entity_id": "s1"]
        let dest = manager.handleNotificationTap(payload: payload)
        #expect(dest == .schoolDetail(id: "s1"))
    }

    @Test func handleTapUnknownPayloadReturnsNil() async {
        let manager = PushNotificationManager(authManager: MockAuthManager())
        let dest = manager.handleNotificationTap(payload: [:])
        #expect(dest == nil)
    }

    // MARK: - Helpers
    // User.id is String (not UUID). fullName has a default value of nil.
    private func makeTestUser(id: String) -> User {
        User(
            id: id, email: "test@example.com",
            emailConfirmedAt: nil, phone: nil,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z",
            role: .player
        )
    }
}
