import Foundation

enum PublicProfileAPIError: LocalizedError, Equatable {
    case unauthorized
    case slugTaken
    case slugInvalid
    case notMember
    case notConfigured
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .slugTaken: return "That custom URL is already taken."
        case .slugInvalid: return "That custom URL is invalid or reserved."
        case .notMember: return "You don't have permission to edit this profile."
        case .notConfigured: return "Public profile is not available."
        case .server: return "Couldn't save changes. Please try again."
        }
    }
}

protocol PublicProfileManaging: Sendable {
    func fetchProfile(accessToken: String?) async throws -> PlayerProfile?
    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws
    func fetchTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink?
    func createTrackingLink(coachId: String, accessToken: String?) async throws
        -> ProfileTrackingLink
}
