import Foundation

final class MockPublicProfileManaging: PublicProfileManaging, @unchecked Sendable {
    var stubProfile: PlayerProfile?
    var stubTrackingLink: ProfileTrackingLink?
    var errorToThrow: Error?
    private(set) var updatedPayloads: [UpdateProfilePayload] = []
    private(set) var createdCoachIds: [String] = []
    private(set) var fetchedTrackingCoachIds: [String] = []

    func fetchProfile(accessToken: String?) async throws -> PlayerProfile? {
        if let errorToThrow { throw errorToThrow }
        return stubProfile
    }

    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws {
        if let errorToThrow { throw errorToThrow }
        updatedPayloads.append(payload)
    }

    func fetchTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink?
    {
        if let errorToThrow { throw errorToThrow }
        fetchedTrackingCoachIds.append(coachId)
        return stubTrackingLink
    }

    func createTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink
    {
        if let errorToThrow { throw errorToThrow }
        createdCoachIds.append(coachId)
        guard let stub = stubTrackingLink else {
            return ProfileTrackingLink(
                id: "mock", profileId: "p1", coachId: coachId,
                refToken: "mock1234", viewCount: 0, lastViewedAt: nil, createdAt: ""
            )
        }
        return stub
    }
}
