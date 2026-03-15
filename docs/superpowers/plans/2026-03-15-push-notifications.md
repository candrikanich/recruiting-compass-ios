# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up end-to-end APNs push delivery for the existing in-app notification center, with per-user per-type push preferences and a Supabase Edge Function trigger.

**Architecture:** A `PushNotificationManager` singleton handles APNs permission, device token upsert/delete, badge count, and deep link routing. A new `notification_preferences` Supabase table stores per-type opt-in state. An Edge Function fires on every `notifications` INSERT, checks preferences, and sends APNs pushes via JWT auth. Destination parsing is extracted into a shared `NotificationDestinationParser` utility so both the push manager and the existing notification list ViewModel can use it without a layering violation.

**Tech Stack:** Swift 5 / SwiftUI / `UserNotifications` framework / Supabase Swift SDK / Supabase Edge Functions (Deno/TypeScript) / APNs HTTP/2 / `jose` JWT library

**Spec:** `docs/superpowers/specs/2026-03-15-push-notifications-design.md`

---

## File Map

### New — iOS

| File | Purpose |
|---|---|
| `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/NotificationDestinationParser.swift` | Pure static parser: `AppNotification` → `NotificationDestination` and APNs payload → `NotificationDestination` |
| `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/PushNotificationManaging.swift` | Protocol + `Notification.Name` extension |
| `TheRecruitingCompass/TheRecruitingCompass/Core/Services/PushNotificationManager.swift` | `@MainActor` singleton, `UNUserNotificationCenterDelegate`, token upsert/delete, badge |
| `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppDelegate.swift` | Bridges `didRegisterForRemoteNotificationsWithDeviceToken` to `PushNotificationManager` |
| `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesManaging.swift` | Protocol for `notification_preferences` table |
| `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesServiceImpl.swift` | Supabase impl — fetch, upsert, seed |

### New — Tests / Mocks

| File | Purpose |
|---|---|
| `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/NotificationDestinationParserTests.swift` | All entity types + action URL + payload |
| `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/PushNotificationManagerTests.swift` | Token register/delete, badge, tap routing |
| `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/NotificationPreferencesPushTests.swift` | VM push state load/toggle |
| `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushNotificationManager.swift` | Test double |
| `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushPreferencesService.swift` | Test double |

### New — Supabase

| File | Purpose |
|---|---|
| `supabase/migrations/20260315000001_add_device_tokens.sql` | `device_tokens` table + RLS |
| `supabase/migrations/20260315000002_add_notification_preferences.sql` | `notification_preferences` table + RLS |
| `supabase/migrations/20260315000003_add_push_trigger.sql` | `pg_net` trigger on `notifications` INSERT |
| `supabase/functions/send-push-notification/index.ts` | Edge Function: check prefs → fetch tokens → send APNs |

### Modified — iOS

| File | Change |
|---|---|
| `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/ViewModels/NotificationsListViewModel.swift` | Replace `private parseDestination/parseActionUrl/extractId` with `NotificationDestinationParser` calls |
| `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/NotificationPreferencesViewModel.swift` | Add `pushPreferences` state + `PushPreferencesManaging` dependency |
| `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/NotificationPreferencesView.swift` | Add "Push Notifications" section + OS permission denied banner |
| `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift` | Seed push prefs on login, delete device token on logout |
| `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift` | Add `@UIApplicationDelegateAdaptor`, wire push permission request, badge sync, deep link |

---

## Chunk 1: iOS Foundation

### Task 1: NotificationDestinationParser

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/NotificationDestinationParser.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/NotificationDestinationParserTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/NotificationDestinationParserTests.swift
import Testing
@testable import TheRecruitingCompass

@Suite("NotificationDestinationParser")
struct NotificationDestinationParserTests {

    // MARK: - from AppNotification (entity type)

    @Test func coachEntityReturnsCoachDetail() {
        let n = makeNotification(entityType: "coach", relatedCoachId: "c1")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "c1"))
    }

    @Test func schoolEntityReturnsSchoolDetail() {
        let n = makeNotification(entityType: "school", relatedSchoolId: "s1")
        #expect(NotificationDestinationParser.destination(from: n) == .schoolDetail(id: "s1"))
    }

    @Test func offerEntityReturnsOfferDetail() {
        let n = makeNotification(entityType: "offer", relatedOfferId: "o1")
        #expect(NotificationDestinationParser.destination(from: n) == .offerDetail(id: "o1"))
    }

    @Test func eventEntityReturnsEventDetail() {
        let n = makeNotification(entityType: "event", relatedEventId: "e1")
        #expect(NotificationDestinationParser.destination(from: n) == .eventDetail(id: "e1"))
    }

    @Test func interactionEntityReturnsInteractionDetail() {
        let n = makeNotification(entityType: "interaction", entityId: "i1")
        #expect(NotificationDestinationParser.destination(from: n) == .interactionDetail(id: "i1"))
    }

    @Test func coachFallsBackToEntityId() {
        let n = makeNotification(entityType: "coach", entityId: "fallback")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "fallback"))
    }

    @Test func unknownEntityTypeReturnsNil() {
        let n = makeNotification(entityType: "widget", entityId: "x")
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    @Test func noEntityTypeReturnsNil() {
        let n = makeNotification(entityType: nil)
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    // MARK: - from AppNotification (actionUrl)

    @Test func coachHighlightUrlReturnsCoachDetail() {
        let n = makeNotification(actionUrl: "/coaches?highlight=c42")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "c42"))
    }

    @Test func schoolPathUrlReturnsSchoolDetail() {
        let n = makeNotification(actionUrl: "/schools/s99")
        #expect(NotificationDestinationParser.destination(from: n) == .schoolDetail(id: "s99"))
    }

    @Test func offerHighlightUrlReturnsOfferDetail() {
        let n = makeNotification(actionUrl: "/offers?highlight=o7")
        #expect(NotificationDestinationParser.destination(from: n) == .offerDetail(id: "o7"))
    }

    @Test func eventPathUrlReturnsEventDetail() {
        let n = makeNotification(actionUrl: "/events/ev3")
        #expect(NotificationDestinationParser.destination(from: n) == .eventDetail(id: "ev3"))
    }

    @Test func unknownUrlReturnsNil() {
        let n = makeNotification(actionUrl: "/dashboard")
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    // MARK: - fromPayload (APNs push)

    @Test func payloadCoachTypeReturnsCoachDetail() {
        let p: [AnyHashable: Any] = ["related_entity_type": "coach", "related_entity_id": "c5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == .coachDetail(id: "c5"))
    }

    @Test func payloadSchoolTypeReturnsSchoolDetail() {
        let p: [AnyHashable: Any] = ["related_entity_type": "school", "related_entity_id": "s5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == .schoolDetail(id: "s5"))
    }

    @Test func payloadMissingTypeReturnsNil() {
        let p: [AnyHashable: Any] = ["related_entity_id": "c5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == nil)
    }

    @Test func payloadMissingIdReturnsNil() {
        let p: [AnyHashable: Any] = ["related_entity_type": "coach"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == nil)
    }

    // MARK: - Helpers

    private func makeNotification(
        entityType: String? = nil,
        entityId: String? = nil,
        relatedCoachId: String? = nil,
        relatedSchoolId: String? = nil,
        relatedOfferId: String? = nil,
        relatedEventId: String? = nil,
        actionUrl: String? = nil
    ) -> AppNotification {
        AppNotification(
            id: "test-id", userId: "user-1", type: .followUpReminder,
            title: "Test", message: "Body", priority: .normal,
            readAt: nil, scheduledFor: "2026-03-15T00:00:00Z",
            sentAt: nil, emailSent: nil, emailSentAt: nil,
            actionUrl: actionUrl,
            relatedEntityType: entityType,
            relatedEntityId: entityId,
            relatedSchoolId: relatedSchoolId,
            relatedCoachId: relatedCoachId,
            relatedOfferId: relatedOfferId,
            relatedEventId: relatedEventId,
            createdAt: nil, updatedAt: nil
        )
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (type not found)**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/NotificationDestinationParserTests \
  -quiet 2>&1 | grep -E "FAILED|error:|passed"
```

Expected: compile error — `NotificationDestinationParser` not found.

- [ ] **Step 3: Create `NotificationDestinationParser.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/NotificationDestinationParser.swift
import Foundation

enum NotificationDestinationParser {

    static func destination(from notification: AppNotification) -> NotificationDestination? {
        if let actionUrl = notification.actionUrl {
            return destination(fromActionUrl: actionUrl)
        }
        guard let entityType = notification.relatedEntityType else { return nil }
        return destination(
            entityType: entityType,
            primaryId: primaryId(for: entityType, notification: notification),
            fallbackId: notification.relatedEntityId
        )
    }

    static func destination(fromPayload payload: [AnyHashable: Any]) -> NotificationDestination? {
        guard let entityType = payload["related_entity_type"] as? String,
              let entityId   = payload["related_entity_id"]   as? String else { return nil }
        return destination(entityType: entityType, primaryId: entityId, fallbackId: nil)
    }

    // MARK: - Private

    private static func primaryId(for entityType: String, notification: AppNotification) -> String? {
        switch entityType {
        case "coach":       return notification.relatedCoachId
        case "school":      return notification.relatedSchoolId
        case "offer":       return notification.relatedOfferId
        case "event":       return notification.relatedEventId
        default:            return nil
        }
    }

    private static func destination(
        entityType: String,
        primaryId: String?,
        fallbackId: String?
    ) -> NotificationDestination? {
        guard let id = primaryId ?? fallbackId else { return nil }
        switch entityType {
        case "coach":       return .coachDetail(id: id)
        case "school":      return .schoolDetail(id: id)
        case "offer":       return .offerDetail(id: id)
        case "event":       return .eventDetail(id: id)
        case "interaction": return .interactionDetail(id: id)
        default:            return nil
        }
    }

    private static func destination(fromActionUrl url: String) -> NotificationDestination? {
        if url.contains("/coaches") {
            return extractId(from: url, pattern: "highlight=").map { .coachDetail(id: $0) }
        } else if url.contains("/schools/") {
            return lastPathComponent(of: url).map { .schoolDetail(id: $0) }
        } else if url.contains("/offers") {
            return extractId(from: url, pattern: "highlight=").map { .offerDetail(id: $0) }
        } else if url.contains("/events/") {
            return lastPathComponent(of: url).map { .eventDetail(id: $0) }
        } else if url.contains("/interactions/") {
            return lastPathComponent(of: url).map { .interactionDetail(id: $0) }
        }
        return nil
    }

    private static func extractId(from url: String, pattern: String) -> String? {
        guard let range = url.range(of: pattern) else { return nil }
        let after = url[range.upperBound...]
        return after.components(separatedBy: "&").first.map(String.init)
    }

    private static func lastPathComponent(of url: String) -> String? {
        let component = url.components(separatedBy: "/").last
        return component.flatMap { $0.isEmpty ? nil : $0 }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/NotificationDestinationParserTests \
  -quiet 2>&1 | grep -E "FAILED|passed"
```

Expected: all tests pass.

- [ ] **Step 5: Update `NotificationsListViewModel.swift` to use the parser**

In `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/ViewModels/NotificationsListViewModel.swift`, replace the three private methods at the bottom with calls to `NotificationDestinationParser`:

```swift
// MARK: - Navigation Parsing

private func parseDestination(from notification: AppNotification) -> NotificationDestination? {
    NotificationDestinationParser.destination(from: notification)
}
```

Delete the private `parseActionUrl(_:)` and `extractId(from:pattern:)` methods entirely.

- [ ] **Step 6: Build to confirm no regressions**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/NotificationDestinationParser.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/ViewModels/NotificationsListViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/NotificationDestinationParserTests.swift
git commit -m "refactor(notifications): extract NotificationDestinationParser to Core/Utilities"
```

---

### Task 2: Push Protocols and Service

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/PushNotificationManaging.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesManaging.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesServiceImpl.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushNotificationManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushPreferencesService.swift`

- [ ] **Step 1: Create `PushNotificationManaging.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/PushNotificationManaging.swift
import Foundation
import UserNotifications

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
```

- [ ] **Step 2: Create `PushPreferencesManaging.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesManaging.swift
import Foundation

protocol PushPreferencesManaging: Sendable {
    func fetchPreferences(userId: String) async throws -> [NotificationType: Bool]
    func updatePreference(userId: String, type: NotificationType, pushEnabled: Bool) async throws
    func seedDefaultPreferences(userId: String) async throws
}
```

- [ ] **Step 3: Create `PushPreferencesServiceImpl.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesServiceImpl.swift
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
```

- [ ] **Step 4: Create `MockPushNotificationManager.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushNotificationManager.swift
import Foundation
@testable import TheRecruitingCompass

// @unchecked Sendable required: protocol is Sendable but test mock uses mutable state
final class MockPushNotificationManager: PushNotificationManaging, @unchecked Sendable {
    nonisolated deinit {}

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
```

- [ ] **Step 5: Create `MockPushPreferencesService.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushPreferencesService.swift
import Foundation
@testable import TheRecruitingCompass

// @unchecked Sendable: mutable state OK in tests (single-threaded test execution)
final class MockPushPreferencesService: PushPreferencesManaging, @unchecked Sendable {
    var preferences: [NotificationType: Bool] = NotificationType.allCases
        .filter { $0 != .unknown }
        .reduce(into: [:]) { $0[$1] = true }
    var updateCalls: [(NotificationType, Bool)] = []
    var seedCalled = false
    var shouldThrow = false

    func fetchPreferences(userId: String) async throws -> [NotificationType: Bool] {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        return preferences
    }

    func updatePreference(userId: String, type: NotificationType, pushEnabled: Bool) async throws {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        preferences[type] = pushEnabled
        updateCalls.append((type, pushEnabled))
    }

    func seedDefaultPreferences(userId: String) async throws {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        seedCalled = true
    }
}
```

- [ ] **Step 6: Build to confirm everything compiles**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/PushNotificationManaging.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesManaging.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Services/PushPreferencesServiceImpl.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushNotificationManager.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockPushPreferencesService.swift
git commit -m "feat(push): add push notification protocols and PushPreferencesServiceImpl"
```

---

## Chunk 2: iOS App Layer

### Task 3: PushNotificationManager

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/PushNotificationManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/PushNotificationManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/PushNotificationManagerTests.swift
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
        let supabase = MockSupabaseManager()
        let manager = PushNotificationManager(supabaseManager: supabase, authManager: authManager)

        let tokenData = Data([0xAB, 0xCD, 0xEF])
        await manager.registerDeviceToken(tokenData)

        #expect(manager.currentTokenStringForTesting == "abcdef")
    }

    @Test func registerDeviceTokenNoOpWhenNoUser() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = nil
        authManager.user = nil
        let manager = PushNotificationManager(supabaseManager: MockSupabaseManager(), authManager: authManager)

        await manager.registerDeviceToken(Data([0x01, 0x02]))

        #expect(manager.currentTokenStringForTesting == nil)
    }

    @Test func deleteDeviceTokenClearsCurrentToken() async {
        let authManager = MockAuthManager()
        authManager.mockUserToReturn = makeTestUser(id: "user-abc")
        authManager.user = authManager.mockUserToReturn
        let manager = PushNotificationManager(supabaseManager: MockSupabaseManager(), authManager: authManager)
        await manager.registerDeviceToken(Data([0xAA]))

        await manager.deleteDeviceToken()

        #expect(manager.currentTokenStringForTesting == nil)
    }

    @Test func clearBadgeCallsUNCenter() async {
        let manager = PushNotificationManager(supabaseManager: MockSupabaseManager(), authManager: MockAuthManager())
        // Should not throw — exercise the path
        manager.clearBadge()
    }

    @Test func handleTapDelegatesToParser() async {
        let manager = PushNotificationManager(supabaseManager: MockSupabaseManager(), authManager: MockAuthManager())
        let payload: [AnyHashable: Any] = ["related_entity_type": "school", "related_entity_id": "s1"]
        let dest = manager.handleNotificationTap(payload: payload)
        #expect(dest == .schoolDetail(id: "s1"))
    }

    @Test func handleTapUnknownPayloadReturnsNil() async {
        let manager = PushNotificationManager(supabaseManager: MockSupabaseManager(), authManager: MockAuthManager())
        let dest = manager.handleNotificationTap(payload: [:])
        #expect(dest == nil)
    }

    // MARK: - Helpers
    // User.id is String (not UUID). Full initializer requires all fields.
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
```

> **Note:** `MockSupabaseManager` already exists in the test target (or create a minimal one). `MockAuthManager` is in `TheRecruitingCompassTests/Mocks/MockAuthManager.swift`. Expose `currentTokenStringForTesting` as an `internal` computed property on `PushNotificationManager` gated by `#if DEBUG`.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PushNotificationManagerTests \
  -quiet 2>&1 | grep -E "FAILED|error:|passed"
```

- [ ] **Step 3: Create `PushNotificationManager.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Core/Services/PushNotificationManager.swift
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

    init(
        supabaseManager: SupabaseManager = .shared,
        authManager: any AuthManaging = AuthManager.shared
    ) {
        self.supabaseManager = supabaseManager
        self.authManager = authManager
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
        // User.id is String — use directly (no .uuidString)
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
        do {
            try await supabaseManager.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()
            currentTokenString = nil
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
                .eq("user_id", value: userId)  // User.id is String
                .is("read_at", value: nil)
                .execute()
            let count = response.count ?? 0
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            logger.error("Badge sync failed: \(error.localizedDescription)")
        }
    }

    func clearBadge() {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
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
        if let destination = NotificationDestinationParser.destination(fromPayload: userInfo) {
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["destination": destination]
            )
        }
        completionHandler()
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PushNotificationManagerTests \
  -quiet 2>&1 | grep -E "FAILED|passed"
```

- [ ] **Step 5: Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Core/Services/PushNotificationManager.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/PushNotificationManagerTests.swift
git commit -m "feat(push): add PushNotificationManager with token management, badge, and deep link routing"
```

---

### Task 4: NotificationPreferencesViewModel — Push Extensions

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/NotificationPreferencesViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/NotificationPreferencesView.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/NotificationPreferencesPushTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/NotificationPreferencesPushTests.swift
import Testing
@testable import TheRecruitingCompass

@Suite("NotificationPreferencesViewModel — push")
@MainActor
struct NotificationPreferencesPushTests {

    @Test func loadFetchesPushPreferencesFromService() async {
        let pushService = MockPushPreferencesService()
        pushService.preferences[.offer] = false
        let vm = NotificationPreferencesViewModel(
            preferenceService: MockPreferenceManaging(),
            pushPreferencesService: pushService
        )
        await vm.loadPushPreferences(userId: "user-test-1")

        #expect(vm.pushPreferences[.offer] == false)
        #expect(vm.pushPreferences[.followUpReminder] == true)
    }

    @Test func updatePushPreferenceCallsService() async {
        let pushService = MockPushPreferencesService()
        let vm = NotificationPreferencesViewModel(
            preferenceService: MockPreferenceManaging(),
            pushPreferencesService: pushService
        )
        await vm.loadPushPreferences(userId: "user-1")
        await vm.updatePushPreference(userId: "user-1", type: .offer, enabled: false)

        #expect(pushService.updateCalls.count == 1)
        #expect(pushService.updateCalls.first?.0 == .offer)
        #expect(pushService.updateCalls.first?.1 == false)
        #expect(vm.pushPreferences[.offer] == false)
    }

    @Test func loadErrorSetsErrorMessage() async {
        let pushService = MockPushPreferencesService()
        pushService.shouldThrow = true
        let vm = NotificationPreferencesViewModel(
            preferenceService: MockPreferenceManaging(),
            pushPreferencesService: pushService
        )
        await vm.loadPushPreferences(userId: "user-1")

        #expect(vm.errorMessage != nil)
    }

    @Test func unknownTypeIsExcludedFromPreferences() async {
        let pushService = MockPushPreferencesService()
        let vm = NotificationPreferencesViewModel(
            preferenceService: MockPreferenceManaging(),
            pushPreferencesService: pushService
        )
        await vm.loadPushPreferences(userId: "user-1")

        #expect(vm.pushPreferences[.unknown] == nil)
    }
}

// Minimal mock for PreferenceManaging (already tested elsewhere)
private final class MockPreferenceManaging: PreferenceManaging {
    func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? { nil }
    func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T { data }
    func deletePreferences(category: PreferenceCategory) async throws {}
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/NotificationPreferencesPushTests \
  -quiet 2>&1 | grep -E "FAILED|error:|passed"
```

- [ ] **Step 3: Update `NotificationPreferencesViewModel.swift`**

Add a second initialiser parameter and new push methods. Keep all existing code intact.

> **Important:** The existing `deinit` in this ViewModel cancels async tasks. Per project requirement, all `@MainActor` class deinits must be `nonisolated`. Convert the existing `deinit` to:
> ```swift
> nonisolated deinit {
>     pendingAutoSave?.cancel()
>     pendingStatusReset?.cancel()
> }
> ```

```swift
// Add at the top of the class body, after existing properties:
var pushPreferences: [NotificationType: Bool] = [:]
private let pushPreferencesService: (any PushPreferencesManaging)?

// Update the existing init to accept the new dependency:
init(
    preferenceService: any PreferenceManaging,
    pushPreferencesService: (any PushPreferencesManaging)? = nil
) {
    self.preferenceService = preferenceService
    self.pushPreferencesService = pushPreferencesService
}

// Add new methods:
func loadPushPreferences(userId: String) async {
    guard let service = pushPreferencesService else { return }
    do {
        let prefs = try await service.fetchPreferences(userId: userId)
        pushPreferences = prefs.filter { $0.key != .unknown }
    } catch {
        errorMessage = "Failed to load push preferences."
        logger.error("loadPushPreferences failed: \(error.localizedDescription)")
    }
}

func updatePushPreference(userId: String, type: NotificationType, enabled: Bool) async {
    guard let service = pushPreferencesService else { return }
    pushPreferences[type] = enabled  // optimistic update
    do {
        try await service.updatePreference(userId: userId, type: type, pushEnabled: enabled)
    } catch {
        pushPreferences[type] = !enabled  // revert
        errorMessage = "Failed to update push preference."
        logger.error("updatePushPreference failed: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 4: Update `NotificationPreferencesView.swift` — add push section**

Add after the existing "Email Notifications" section, before the "Actions" section:

```swift
// Push Notifications Section
Section {
    if pushAuthStatus == .denied {
        HStack {
            Image(systemName: "bell.slash")
                .foregroundStyle(.secondary)
            Text("Push notifications are disabled in iOS Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Push notifications disabled. Open Settings to enable.")
    } else {
        ForEach(NotificationType.allCases.filter { $0 != .unknown }, id: \.self) { type in
            Toggle(type.label, isOn: Binding(
                get: { viewModel.pushPreferences[type] ?? true },
                set: { enabled in
                    guard let userId = authManager.user?.id else { return }
                    Task { await viewModel.updatePushPreference(userId: userId, type: type, enabled: enabled) }
                }
            ))
            .accessibilityLabel("Push notifications for \(type.label)")
        }
    }
} header: {
    Text("Push Notifications")
} footer: {
    Text("Controls which notification types trigger a push alert on your device.")
        .font(.caption)
}
```

Add to the View struct:
```swift
@Environment(\.openURL) private var openURL
@Environment(AuthManager.self) private var authManager
@State private var pushAuthStatus: UNAuthorizationStatus = .notDetermined

// Add to .task:
let settings = await UNUserNotificationCenter.current().notificationSettings()
pushAuthStatus = settings.authorizationStatus
```

Also inject `pushPreferencesService` in `NotificationPreferencesView.init` and pass it to the ViewModel:
```swift
init(preferenceService: any PreferenceManaging, pushPreferencesService: (any PushPreferencesManaging)? = nil) {
    _viewModel = State(initialValue: NotificationPreferencesViewModel(
        preferenceService: preferenceService,
        pushPreferencesService: pushPreferencesService
    ))
}
```

In the `.task` modifier, also load push preferences:
```swift
if let userId = authManager.user?.id {
    await viewModel.loadPushPreferences(userId: userId)
}
```

> **Note:** `UNAuthorizationStatus` and `UNUserNotificationCenter` require `import UserNotifications` at the top of the View file.

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/NotificationPreferencesPushTests \
  -quiet 2>&1 | grep -E "FAILED|passed"
```

- [ ] **Step 6: Full build check**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

- [ ] **Step 7: Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/NotificationPreferencesViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/NotificationPreferencesView.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/NotificationPreferencesPushTests.swift
git commit -m "feat(push): add push preferences UI and ViewModel extensions"
```

---

### Task 5: App Wiring

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppDelegate.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`

- [ ] **Step 1: Create `AppDelegate.swift`**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppDelegate.swift
import UIKit
import OSLog

private let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "AppDelegate"
)

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushNotificationManager.shared.registerDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal — app works without push
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 2: Wire up `TheRecruitingCompassApp.swift`**

Add the following to `TheRecruitingCompassApp`:

```swift
// At top of struct body — after existing @State properties:
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

In the `WindowGroup` body, add to the root `.task` or to the authenticated-state view's `.task`:

```swift
// On the authenticated root view (AuthenticatedContent or its parent Group):
.task {
    // Set push delegate once
    UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
    // Request permission after auth is established
    await PushNotificationManager.shared.requestPermission()
    // Sync badge on launch
    await PushNotificationManager.shared.syncBadgeCount()
    // Seed push preferences
    if let userId = authManager.user?.id {
        try? await PushPreferencesServiceImpl().seedDefaultPreferences(userId: userId)
    }
}
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    Task { await PushNotificationManager.shared.syncBadgeCount() }
}
.onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
    if let destination = notification.userInfo?["destination"] as? NotificationDestination {
        // Route to destination using the existing navigation pattern.
        // Add @State var pendingPushDestination: NotificationDestination? to TheRecruitingCompassApp
        // and pass it into AuthenticatedContent, then let each tab's NavigationStack handle it.
        // Follow the same pattern as pendingResetPasswordFromDeepLink in this file.
        pendingPushDestination = destination
    }
}
```

- [ ] **Step 3: Update `AuthManager.logout()` to delete device token**

In `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`, add token deletion at the start of `logout()`:

```swift
func logout() async throws {
    // Delete device token before clearing user identity
    await PushNotificationManager.shared.deleteDeviceToken()

    do {
        try await supabaseManager.signOut()
    } catch {
        logger.warning("Sign-out from Supabase failed, local session will be cleared: \(error.localizedDescription)")
    }
    // ... rest of existing logout code unchanged ...
}
```

- [ ] **Step 4: Full build + unit test run**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skip-testing:TheRecruitingCompassUITests \
  -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|FAILED|passed [0-9]"
```

Expected: `BUILD SUCCEEDED`, all existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppDelegate.swift \
  TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift \
  TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift
git commit -m "feat(push): wire PushNotificationManager into app lifecycle and logout"
```

---

## Chunk 3: Supabase Backend

### Task 6: Database Migrations

**Files:**
- Create: `supabase/migrations/20260315000001_add_device_tokens.sql`
- Create: `supabase/migrations/20260315000002_add_notification_preferences.sql`

- [ ] **Step 1: Create `device_tokens` migration**

```sql
-- supabase/migrations/20260315000001_add_device_tokens.sql
CREATE TABLE IF NOT EXISTS device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users NOT NULL,
  token       text NOT NULL,
  platform    text NOT NULL DEFAULT 'ios',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens: users manage own"
  ON device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 2: Create `notification_preferences` migration**

```sql
-- supabase/migrations/20260315000002_add_notification_preferences.sql
CREATE TABLE IF NOT EXISTS notification_preferences (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid REFERENCES auth.users NOT NULL,
  notification_type   text NOT NULL
    CHECK (notification_type IN (
      'follow_up_reminder', 'deadline_alert', 'daily_digest',
      'inbound_interaction', 'offer', 'event'
    )),
  push_enabled        bool NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, notification_type)
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences: users manage own"
  ON notification_preferences FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 3: Run migrations in Supabase dashboard or via CLI**

Via Supabase CLI:
```bash
supabase db push
```

Or apply manually via Supabase Dashboard → SQL Editor.

Verify:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('device_tokens', 'notification_preferences');
```

Expected: 2 rows returned.

- [ ] **Step 4: Commit migration files**

```bash
git add supabase/migrations/20260315000001_add_device_tokens.sql \
        supabase/migrations/20260315000002_add_notification_preferences.sql
git commit -m "feat(push): add device_tokens and notification_preferences migrations"
```

---

### Task 7: Edge Function

**Files:**
- Create: `supabase/functions/send-push-notification/index.ts`

- [ ] **Step 1: Store APNs secrets in Supabase**

In Supabase Dashboard → Settings → Edge Functions → Secrets, add:
```
APNS_KEY_ID       = <10-char key ID from Apple Developer portal>
APNS_TEAM_ID      = <10-char team ID from Apple Developer portal>
APNS_PRIVATE_KEY  = <full contents of .p8 file including -----BEGIN/END PRIVATE KEY----- lines>
APNS_BUNDLE_ID    = com.chrisandrikanich.TheRecruitingCompass
APNS_ENVIRONMENT  = sandbox   # change to "production" for TestFlight/App Store
```

- [ ] **Step 2: Create the Edge Function**

```typescript
// supabase/functions/send-push-notification/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5";

const APNS_HOST = Deno.env.get("APNS_ENVIRONMENT") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  related_entity_type?: string;
  related_entity_id?: string;
}

Deno.serve(async (req) => {
  try {
    const notification: NotificationRow = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Check push preference (no row = send by default)
    const { data: pref } = await supabase
      .from("notification_preferences")
      .select("push_enabled")
      .eq("user_id", notification.user_id)
      .eq("notification_type", notification.type)
      .maybeSingle();

    if (pref?.push_enabled === false) {
      return new Response("push disabled for type", { status: 200 });
    }

    // 2. Fetch device tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", notification.user_id)
      .eq("platform", "ios");

    if (!tokens?.length) {
      return new Response("no device tokens", { status: 200 });
    }

    // 3. Unread badge count
    const { count: badgeCount } = await supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", notification.user_id)
      .is("read_at", null);

    // 4. Build APNs JWT
    const apnsJwt = await buildApnsJwt();

    // 5. Send to each device token
    let atLeastOneSuccess = false;
    const staleTokens: string[] = [];

    for (const { token } of tokens) {
      const result = await sendApnsPush({
        deviceToken: token,
        jwt: apnsJwt,
        title: notification.title,
        body: notification.message,
        badge: badgeCount ?? 0,
        data: {
          notification_id: notification.id,
          related_entity_type: notification.related_entity_type,
          related_entity_id: notification.related_entity_id,
        },
      });

      if (result.status === 200) {
        atLeastOneSuccess = true;
      } else if (result.status === 410) {
        staleTokens.push(token);
      } else {
        console.error(`APNs error ${result.status} for token ${token.slice(0, 8)}...`);
      }
    }

    // 6. Clean up stale tokens
    if (staleTokens.length) {
      await supabase
        .from("device_tokens")
        .delete()
        .eq("user_id", notification.user_id)
        .in("token", staleTokens);
    }

    // 7. Mark sent_at if at least one delivery succeeded
    if (atLeastOneSuccess) {
      await supabase
        .from("notifications")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", notification.id);
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return new Response("internal error", { status: 500 });
  }
});

// MARK: - APNs Helpers

async function buildApnsJwt(): Promise<string> {
  const keyId   = Deno.env.get("APNS_KEY_ID")!;
  const teamId  = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey  = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKey = await importPKCS8(rawKey, "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);
}

async function sendApnsPush(opts: {
  deviceToken: string;
  jwt: string;
  title: string;
  body: string;
  badge: number;
  data: Record<string, string | undefined>;
}): Promise<Response> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const url = `${APNS_HOST}/3/device/${opts.deviceToken}`;

  const payload = {
    aps: {
      alert: { title: opts.title, body: opts.body },
      badge: opts.badge,
      sound: "default",
    },
    ...opts.data,
  };

  return fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${opts.jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}
```

- [ ] **Step 3: Deploy the Edge Function**

```bash
supabase functions deploy send-push-notification --no-verify-jwt
```

The `--no-verify-jwt` flag is correct here — this function is called from a Postgres trigger using the service role, not a user JWT.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/send-push-notification/index.ts
git commit -m "feat(push): add send-push-notification Edge Function"
```

---

### Task 8: DB Trigger

**Files:**
- Create: `supabase/migrations/20260315000003_add_push_trigger.sql`

- [ ] **Step 1: Verify pg_net is enabled**

In Supabase Dashboard → SQL Editor:
```sql
SELECT extname FROM pg_extension WHERE extname = 'pg_net';
```

Expected: 1 row. If missing, enable it via Supabase Dashboard → Database → Extensions → pg_net.

- [ ] **Step 2: Create trigger migration**

> **pg_net API note:** Supabase uses `net.http_post` (from the `pg_net` extension) directly. The `supabase_functions.http_request` wrapper exists but `net.http_post` with named parameters is the stable API for Supabase hosted projects.
>
> **Service role key:** On Supabase hosted, the Edge Function receives `SUPABASE_SERVICE_ROLE_KEY` automatically as an env var — you do NOT need to pass an `Authorization` header from the trigger. However, the function must accept unauthenticated calls (deployed with `--no-verify-jwt`). Store the project ref as a Postgres setting so it never appears in version-controlled SQL.

Run once in SQL Editor (not in migration file — keeps secret out of source control):
```sql
ALTER DATABASE postgres SET app.edge_function_base_url = 'https://<PROJECT-REF>.supabase.co/functions/v1';
```

```sql
-- supabase/migrations/20260315000003_add_push_trigger.sql

CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := current_setting('app.edge_function_base_url') || '/send-push-notification',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body    := to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER push_on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_push_notification();
```

The service role key is NOT in the trigger — the Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` auto-injected by the Supabase runtime to call back into the database.

- [ ] **Step 3: Apply migration and smoke-test**

```bash
supabase db push
```

Then smoke-test by inserting a notification directly:
```sql
INSERT INTO notifications (
  user_id, type, title, message, priority, scheduled_for
) VALUES (
  '<your-test-user-id>',
  'follow_up_reminder',
  'Test Push',
  'This is a test push notification',
  'normal',
  now()
);
```

Verify: push arrives on a connected device with a registered token, or check Edge Function logs in Supabase Dashboard → Edge Functions → Logs.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260315000003_add_push_trigger.sql
git commit -m "feat(push): add Postgres trigger to fire push notifications on INSERT"
```

---

## Final Verification Checklist

After all tasks complete, run the full test suite:

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skip-testing:TheRecruitingCompassUITests \
  -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|FAILED|passed [0-9]"
```

Expected: `BUILD SUCCEEDED`, all tests pass.

**Manual verification steps:**
1. Build and run on a physical device (push does not work on Simulator)
2. Grant push permission on first launch after onboarding
3. Insert a notification row via Supabase Dashboard → verify push arrives
4. Tap push → verify app navigates to correct entity
5. Open Notification Center in app → verify badge clears
6. Disable a type in Preferences → insert that notification type → verify no push
7. Sign out → insert notification → verify no push arrives on signed-out device
