import Foundation

final class MockPublicProfileManaging: PublicProfileManaging, @unchecked Sendable {
    var stubProfile: PlayerProfile?
    var stubTrackingLink: ProfileTrackingLink?
    var errorToThrow: Error?
    /// Thrown by the next profile fetch/update only, then cleared — models a 401 that a token refresh fixes.
    var errorToThrowOnce: Error?
    /// Runs inside `createTrackingLink`, i.e. while a send is mid-flight.
    var onCreateTrackingLink: (() async -> Void)?
    /// Thrown by `createTrackingLink` only, leaving link fetches alone.
    var createTrackingLinkError: Error?
    /// Runs at the start of `fetchProfile`, i.e. while a load is mid-flight.
    var onFetchProfile: (() async -> Void)?
    var onFetchTrackingLink: (() async -> Void)?
    private(set) var fetchedAthleteIds: [String?] = []
    private(set) var updatedPayloads: [UpdateProfilePayload] = []
    /// Every `updateProfile` call, including ones that threw — `updatedPayloads` only has successes.
    private(set) var attemptedPayloads: [UpdateProfilePayload] = []
    private(set) var createdCoachIds: [String] = []
    private(set) var fetchedTrackingCoachIds: [String] = []
    private(set) var fetchedTrackingAthleteIds: [String?] = []
    private(set) var createdTrackingAthleteIds: [String?] = []

    func fetchProfile(athleteId: String?, accessToken: String?) async throws -> PlayerProfile? {
        fetchedAthleteIds.append(athleteId)
        await onFetchProfile?()
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

    func fetchTrackingLink(coachId: String, athleteId: String?, accessToken: String?) async throws
        -> ProfileTrackingLink? {
        await onFetchTrackingLink?()
        if let errorToThrow { throw errorToThrow }
        fetchedTrackingCoachIds.append(coachId)
        fetchedTrackingAthleteIds.append(athleteId)
        return stubTrackingLink
    }

    func createTrackingLink(coachId: String, athleteId: String?, accessToken: String?) async throws
        -> ProfileTrackingLink {
        await onCreateTrackingLink?()
        if let errorToThrow { throw errorToThrow }
        if let createTrackingLinkError { throw createTrackingLinkError }
        createdCoachIds.append(coachId)
        createdTrackingAthleteIds.append(athleteId)
        guard let stub = stubTrackingLink else {
            return ProfileTrackingLink(
                id: "mock", profileId: "p1", coachId: coachId,
                refToken: "mock1234", viewCount: 0, lastViewedAt: nil, createdAt: ""
            )
        }
        return stub
    }
}
