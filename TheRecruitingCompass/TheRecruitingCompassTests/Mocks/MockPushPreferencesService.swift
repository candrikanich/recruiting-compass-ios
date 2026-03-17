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
