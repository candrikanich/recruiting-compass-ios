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
    private let guardianService: GuardianManaging
    private let familyManager: FamilyManager

    /// Set when a send is attempted on an unpublished profile.
    var notPublishedPrompt = false
    /// Set when a send is attempted while the player's guardian hasn't confirmed yet.
    var guardianPendingPrompt = false
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
        authManager: AuthManaging,
        preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared),
        photoService: ProfilePhotoManaging = ProfilePhotoServiceImpl(),
        interactionsService: InteractionsManaging = InteractionsServiceImpl(supabaseManager: .shared),
        guardianService: GuardianManaging = GuardianServiceImpl(),
        familyManager: FamilyManager? = nil
    ) {
        self.service = service
        self.authManager = authManager
        self.preferenceService = preferenceService
        self.photoService = photoService
        self.interactionsService = interactionsService
        self.guardianService = guardianService
        self.familyManager = familyManager ?? .shared
    }

    /// Identity of the athlete this screen would send for; the view keys its load on it so a
    /// selection change (or family data arriving late) reloads the Send Profile state.
    var selectionKey: String {
        guard case let .resolved(athleteId) = target else { return "" }
        return athleteId ?? authManager.user?.id ?? ""
    }

    /// Load publish state plus any already-generated tracking link for this coach,
    /// so the view can offer copy-link and show view stats (web parity).
    func loadTrackingInfo(for coachId: String) async {
        let token = authManager.session?.accessToken
        let loadedTarget = target
        guard let profile = await fetchSelectedProfile(target: loadedTarget, token: token) else {
            guard loadedTarget == target else { return }
            clearTrackingInfo()
            return
        }
        guard case let .resolved(athleteId) = loadedTarget else { return }
        let link = profile.isPublished
            ? try? await service.fetchTrackingLink(coachId: coachId, athleteId: athleteId, accessToken: token)
            : nil
        // A newer load owns the state once the selection moved on.
        guard loadedTarget == target else { return }
        isPublished = profile.isPublished
        guard let link else {
            clearTrackingInfo(keepingPublished: true)
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
        guardianPendingPrompt = false
        let token = authManager.session?.accessToken
        let preparedTarget = target

        guard case let .resolved(athleteId) = preparedTarget,
              let profile = await fetchSelectedProfile(target: preparedTarget, token: token) else {
            return failSend()
        }
        guard profile.isPublished else {
            notPublishedPrompt = true
            return .notPublished
        }
        isPublished = true

        // COPPA-adjacent lock: a self-signed-up 13-17 player can't share their profile
        // until their named guardian confirms, independent of the publish toggle. Fails
        // open on any lookup error — matches the rest of the guardian-gating in this app.
        if let token, let status = try? await guardianService.fetchStatus(accessToken: token), status.locked {
            guardianPendingPrompt = true
            return .guardianPending
        }

        guard let playerName = await resolvePlayerName(athleteUserId: profile.userId) else {
            return failSend()
        }
        let details: PlayerDetails? = try? await preferenceService.fetchPreferences(
            category: .player, userId: profile.userId
        )
        let positions = CanonicalPositions.formatPositionsShort(
            sport: details?.primarySport,
            positions: details?.positions,
            fallback: details?.primaryPosition
        )

        guard let link = try? await service.createTrackingLink(
                  coachId: coach.id, athleteId: athleteId, accessToken: token
              ),
              let url = buildURL(profile: profile, refToken: link.refToken) else {
            return failSend()
        }
        // The selection can change while the lookups above are in flight; never send for a different athlete.
        guard preparedTarget == target else { return failSend() }
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
        do {
            let request = try InteractionCreateRequest(
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

    private enum Target: Equatable {
        /// `athleteId` nil = the caller's own row (player); non-nil = the parent's selected athlete.
        case resolved(athleteId: String?)
        /// A parent with no athlete selected has no profile of their own to fall back on.
        case none
    }

    private var target: Target {
        let user = authManager.user
        guard let targetUserId = PublicProfileTarget.userId(
            user: user, selectedAthleteUserId: familyManager.selectedAthlete?.userId
        ) else { return .none }
        return .resolved(athleteId: Self.sameUser(targetUserId, user?.id) ? nil : targetUserId)
    }

    /// The single profile fetch behind every entry point. Only returns a row owned by the targeted
    /// athlete, so a mismatched server response can never be sent or offered as a link.
    private func fetchSelectedProfile(target: Target, token: String?) async -> PlayerProfile? {
        guard case let .resolved(athleteId) = target,
              let profile = try? await service.fetchProfile(athleteId: athleteId, accessToken: token),
              let expectedUserId = athleteId ?? authManager.user?.id,
              Self.sameUser(profile.userId, expectedUserId) else { return nil }
        return profile
    }

    /// Ids compare case-insensitively: Swift's `UUID.uuidString` is uppercase while Postgres returns lowercase.
    private static func sameUser(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs else { return false }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private func failSend() -> SendProfilePreparation {
        errorMessage = String(localized: "Couldn't prepare the profile to send. Please try again.")
        return .failed
    }

    private func clearTrackingInfo(keepingPublished: Bool = false) {
        if !keepingPublished { isPublished = false }
        trackingURL = nil
        viewCount = nil
        lastViewedAt = nil
    }

    /// The athlete's display name, or nil when it can't be determined — a coach must never get a blank
    /// name. When a parent sends the athlete's profile the session name is the parent's, so look it up.
    private func resolvePlayerName(athleteUserId: String) async -> String? {
        let name: String?
        if Self.sameUser(athleteUserId, authManager.user?.id) {
            name = authManager.user?.fullName
        } else {
            name = try? await photoService.fullName(userId: athleteUserId)
        }
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return name
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
