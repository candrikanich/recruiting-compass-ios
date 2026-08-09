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
    func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? { nil }
    func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T { data }
    func deletePreferences(category: PreferenceCategory) async throws {}
}
