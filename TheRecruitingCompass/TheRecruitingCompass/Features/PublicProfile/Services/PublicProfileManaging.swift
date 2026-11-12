import Foundation

enum PublicProfileAPIError: LocalizedError, Equatable {
    case unauthorized
    case slugTaken
    case slugInvalid
    case notMember
    case notConfigured
    /// 400 `family_context_required`: a multi-family caller sent no family (web#1045).
    case familyContextRequired
    /// 400 `invalid_family_context`: the family id was malformed.
    case invalidFamilyContext
    case server(Int)
    /// Server-provided message (403/404/400 from `/api/player/profile`), shown verbatim.
    case serverMessage(String)

    /// The family-context errors are the ones the person can fix by switching family.
    var isFamilyContext: Bool { self == .familyContextRequired || self == .invalidFamilyContext }

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .slugTaken: return "That custom URL is already taken."
        case .slugInvalid: return "That custom URL is invalid or reserved."
        case .notMember: return "You don't have permission to edit this profile."
        case .notConfigured: return "Public profile is not available."
        case .familyContextRequired, .invalidFamilyContext:
            return "Couldn't make the tracking link for this family. Pick the family in the switcher and try again."
        case .serverMessage(let message): return message
        case .server: return "Couldn't save changes. Please try again."
        }
    }
}

protocol PublicProfileManaging: Sendable {
    func fetchProfile(athleteId: String?, accessToken: String?) async throws -> PlayerProfile?
    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws
    func fetchTrackingLink(coachId: String, athleteId: String?, accessToken: String?) async throws
        -> ProfileTrackingLink?
    func createTrackingLink(coachId: String, athleteId: String?, accessToken: String?) async throws
        -> ProfileTrackingLink
}
