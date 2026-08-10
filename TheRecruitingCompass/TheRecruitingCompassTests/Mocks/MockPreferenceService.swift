import Foundation
@testable import TheRecruitingCompass

/// Minimal `PreferenceManaging` mock: only `.player` category is stubbed since it's the only
/// category `PublicProfileViewModel.assembleCard()` reads. Other categories return nil.
final class MockPreferenceService: PreferenceManaging, @unchecked Sendable {
    var stubbedPlayerDetails: PlayerDetails?
    var errorToThrow: Error?
    private(set) var fetchedUserIds: [String?] = []

    func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? {
        if let errorToThrow { throw errorToThrow }
        fetchedUserIds.append(userId)
        guard category == .player else { return nil }
        return stubbedPlayerDetails as? T
    }

    func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T {
        if let errorToThrow { throw errorToThrow }
        return data
    }

    func deletePreferences(category: PreferenceCategory) async throws {
        if let errorToThrow { throw errorToThrow }
    }
}
