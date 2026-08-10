import Foundation

enum PublicProfileAPIError: Error, Equatable {
    case unauthorized
    case slugTaken
    case slugInvalid
    case notMember
    case notConfigured
    case server(Int)
}

protocol PublicProfileManaging: Sendable {
    func fetchProfile(accessToken: String?) async throws -> PlayerProfile?
    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws
    func fetchTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink?
    func createTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink
}
