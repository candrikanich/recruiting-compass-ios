import Foundation

final class MockPublicProfileManaging: PublicProfileManaging, @unchecked Sendable {
    var stubProfile: PlayerProfile?
    var stubTrackingLink: ProfileTrackingLink?
    var errorToThrow: Error?
    /// Thrown by the next profile fetch/update only, then cleared — models a 401 that a token refresh fixes.
    var errorToThrowOnce: Error?
    private(set) var fetchedAthleteIds: [String?] = []
    private(set) var updatedPayloads: [UpdateProfilePayload] = []
    /// Every `updateProfile` call, including ones that threw — `updatedPayloads` only has successes.
    private(set) var attemptedPayloads: [UpdateProfilePayload] = []
    private(set) var createdCoachIds: [String] = []
    private(set) var fetchedTrackingCoachIds: [String] = []

    func fetchProfile(athleteId: String?, accessToken: String?) async throws -> PlayerProfile? {
        fetchedAthleteIds.append(athleteId)
        if let once = errorToThrowOnce {
            errorToThrowOnce = nil
            throw once
        }
        if let errorToThrow { throw errorToThrow }
        return stubProfile
    }

    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws {
        if let once = errorToThrowOnce {
            errorToThrowOnce = nil
            attemptedPayloads.append(payload)
            throw once
        }
        attemptedPayloads.append(payload)
        if let errorToThrow { throw errorToThrow }
        updatedPayloads.append(payload)
    }

    func fetchTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink? {
        if let errorToThrow { throw errorToThrow }
        fetchedTrackingCoachIds.append(coachId)
        return stubTrackingLink
    }

    func createTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink {
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
