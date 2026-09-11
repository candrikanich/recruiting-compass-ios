import Foundation
@testable import TheRecruitingCompass

/// `PreferenceManaging` mock. Stub `.player` and `.dashboard`; other categories return nil.
final class MockPreferenceService: PreferenceManaging, @unchecked Sendable {
    var stubbedPlayerDetails: PlayerDetails?
    var stubbedDashboardVisibility: DashboardWidgetVisibility?
    var stubbedHomeLocation: HomeLocation?
    var errorToThrow: Error?
    private(set) var fetchedUserIds: [String?] = []
    private(set) var savedUserIds: [String?] = []
    private(set) var savedPlayerDetails: PlayerDetails?
    private(set) var savedHomeLocation: HomeLocation?
    private(set) var saveCallCount = 0

    func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? {
        if let errorToThrow { throw errorToThrow }
        fetchedUserIds.append(userId)
        switch category {
        case .player:
            return stubbedPlayerDetails as? T
        case .dashboard:
            return stubbedDashboardVisibility as? T
        case .location:
            return stubbedHomeLocation as? T
        default:
            return nil
        }
    }

    func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T {
        if let errorToThrow { throw errorToThrow }
        saveCallCount += 1
        savedUserIds.append(userId)
        if let playerDetails = data as? PlayerDetails {
            savedPlayerDetails = playerDetails
        }
        if let homeLocation = data as? HomeLocation {
            savedHomeLocation = homeLocation
        }
        return data
    }

    func deletePreferences(category: PreferenceCategory) async throws {
        if let errorToThrow { throw errorToThrow }
    }
}
