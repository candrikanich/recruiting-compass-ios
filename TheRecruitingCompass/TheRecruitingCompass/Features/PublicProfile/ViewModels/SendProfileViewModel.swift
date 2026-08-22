import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class SendProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    private let preferenceService: PreferenceManaging
    private let photoService: ProfilePhotoManaging
    private let interactionsService: InteractionsManaging

    /// Set when a send is attempted on an unpublished profile.
    var notPublishedPrompt = false
    /// Drives whether the "Send Profile" button is offered — a profile must be
    /// published before it can be shared with a coach.
    var isPublished = false
    /// The already-generated shareable link for this coach (web parity: copy-link
    /// + view stats). `nil` until a link has been created for the coach.
    var trackingURL: URL?
    var viewCount: Int?
    var lastViewedAt: String?
    var errorMessage: String?
    var successMessage: String?

    init(
        service: PublicProfileManaging = PublicProfileServiceImpl(),
        authManager: AuthManaging = AuthManager.shared,
        preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared),
        photoService: ProfilePhotoManaging = ProfilePhotoServiceImpl(),
        interactionsService: InteractionsManaging = InteractionsServiceImpl(supabaseManager: .shared)
    ) {
        self.service = service
        self.authManager = authManager
        self.preferenceService = preferenceService
        self.photoService = photoService
        self.interactionsService = interactionsService
    }

    /// Load the profile's publish state so the view can hide the Send Profile
    /// button until the profile is public.
    func loadPublishState() async {
        let token = authManager.session?.accessToken
        let profile = try? await service.fetchProfile(accessToken: token)
        isPublished = profile?.isPublished ?? false
    }

    /// Load publish state plus any already-generated tracking link for this coach,
    /// so the view can offer copy-link and show view stats (web parity).
    func loadTrackingInfo(for coachId: String) async {
        let token = authManager.session?.accessToken
        guard let profile = try? await service.fetchProfile(accessToken: token) else {
            isPublished = false
            return
        }
        isPublished = profile.isPublished
        guard profile.isPublished,
              let link = try? await service.fetchTrackingLink(coachId: coachId, accessToken: token) else {
            trackingURL = nil
            viewCount = nil
            lastViewedAt = nil
            return
        }
        trackingURL = buildURL(profile: profile, refToken: link.refToken)
        viewCount = link.viewCount
        lastViewedAt = link.lastViewedAt
    }

    /// Validate, build the tracking URL + boilerplate copy, and decide which
    /// channel(s) the coach exposes. The view presents the matching composer.
    func prepare(for coach: Coach) async -> SendProfilePreparation {
        notPublishedPrompt = false
        let token = authManager.session?.accessToken

        guard let profile = try? await service.fetchProfile(accessToken: token) else {
            return .failed
        }
        guard profile.isPublished else {
            notPublishedPrompt = true
            return .notPublished
        }
        isPublished = true

        let playerName = await resolvePlayerName(athleteUserId: profile.userId)
        let details: PlayerDetails? = try? await preferenceService.fetchPreferences(
            category: .player, userId: profile.userId
        )
        let positions = CanonicalPositions.formatPositionsShort(
            sport: details?.primarySport,
            positions: details?.positions,
            fallback: details?.primaryPosition
        )

        guard let link = try? await service.createTrackingLink(coachId: coach.id, accessToken: token),
              let url = buildURL(profile: profile, refToken: link.refToken) else {
            return .failed
        }
        // Surface the link for copy + view stats now that it exists.
        trackingURL = url
        viewCount = link.viewCount
        lastViewedAt = link.lastViewedAt

        let message = SendProfileMessage(
            coachId: coach.id,
            schoolId: coach.schoolId,
            familyUnitId: profile.familyUnitId,
            coachEmail: coach.contactEmail,
            coachPhone: coach.contactPhone,
            subject: SendProfileCopy.subject(
                playerName: playerName, graduationYear: details?.graduationYear, positions: positions
            ),
            emailBody: SendProfileCopy.emailBody(
                playerName: playerName, coachLastName: coach.lastName, url: url
            ),
            textBody: SendProfileCopy.textBody(
                playerName: playerName, graduationYear: details?.graduationYear, url: url
            ),
            url: url
        )

        switch SendProfileCopy.channel(email: coach.contactEmail, phone: coach.contactPhone) {
        case .email: return .email(message)
        case .text: return .text(message)
        case .both: return .choice(message)
        case .none: return .share(url)
        }
    }

    /// Log an outbound interaction for a profile the composer confirmed as sent.
    /// Call ONLY on a confirmed send — never on cancel/fail — so the app never
    /// records a message that wasn't actually sent.
    func logSend(_ channel: SendProfileChannel, message: SendProfileMessage) async {
        guard let loggedBy = authManager.user?.id else {
            errorMessage = String(localized: "Profile sent, but logging it failed.")
            return
        }
        let request = InteractionCreateRequest(
            schoolId: message.schoolId,
            coachId: message.coachId,
            type: channel == .email ? .email : .text,
            direction: .outbound,
            occurredAt: Date(),
            subject: message.subject,
            content: message.url.absoluteString,
            sentiment: nil,
            loggedBy: loggedBy,
            familyUnitId: message.familyUnitId
        )
        do {
            _ = try await interactionsService.createInteraction(request)
            successMessage = String(localized: "Logged profile sent to coach.")
        } catch {
            errorMessage = String(localized: "Profile sent, but logging it failed.")
        }
    }

    /// Copy the current tracking link to the pasteboard. No-op if none exists.
    func copyTrackingLink() {
        guard let url = trackingURL else { return }
        UIPasteboard.general.string = url.absoluteString
    }

    // MARK: - Private

    /// The athlete's display name. When a parent sends the athlete's profile, the
    /// session name is the parent's — look up the athlete's name (RLS-gated).
    private func resolvePlayerName(athleteUserId: String) async -> String {
        if athleteUserId == authManager.user?.id {
            return authManager.user?.fullName ?? ""
        }
        return (try? await photoService.fullName(userId: athleteUserId)) ?? ""
    }

    private func buildURL(profile: PlayerProfile, refToken: String) -> URL? {
        guard let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = profile.vanitySlug.flatMap { $0.isEmpty ? nil : $0 } ?? profile.hashSlug
        var comps = URLComponents(
            url: base.appendingPathComponent("p").appendingPathComponent(slug),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "ref", value: refToken)]
        return comps?.url
    }
}
