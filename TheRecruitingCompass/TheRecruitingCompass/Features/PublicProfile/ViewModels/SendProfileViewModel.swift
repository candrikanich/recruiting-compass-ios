import Foundation
import Observation

@Observable
@MainActor
final class SendProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    var notPublishedPrompt = false

    init(service: PublicProfileManaging, authManager: AuthManaging) {
        self.service = service
        self.authManager = authManager
    }

    func shareURL(forCoachId coachId: String) async -> URL? {
        notPublishedPrompt = false
        let token = authManager.session?.accessToken
        guard let profile = try? await service.fetchProfile(accessToken: token) else { return nil }
        guard profile.isPublished else {
            notPublishedPrompt = true
            return nil
        }
        guard let link = try? await service.createTrackingLink(coachId: coachId, accessToken: token) else {
            return nil
        }
        guard let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = profile.vanitySlug.flatMap { $0.isEmpty ? nil : $0 } ?? profile.hashSlug
        var comps = URLComponents(
            url: base.appendingPathComponent("p").appendingPathComponent(slug),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "ref", value: link.refToken)]
        return comps?.url
    }
}
