import Foundation
import Observation

@Observable
@MainActor
final class PublicProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    private let targetUserId: String?
    private let familyUnitId: String?
    private let preferenceService: PreferenceManaging
    private let schoolsService: SchoolsManaging
    private let videoLinksService: VideoLinksManaging
    private let photoService: ProfilePhotoManaging

    var profile: PlayerProfile?
    var bio: String = ""
    var vanitySlug: String = ""
    var isPublished: Bool = false
    var headerColor: HeaderColor = .slate
    var showAcademics = true
    var showAthletic = true
    var showFilm = true
    var showSchools = true
    var isLoading = false
    var slugError: String?
    var saveError: String?
    private(set) var cardData: PublicProfileData?

    var isConfigured: Bool { SupabaseConfig.apiBaseURL != nil }

    init(
        service: PublicProfileManaging,
        authManager: AuthManaging,
        targetUserId: String? = nil,
        familyUnitId: String? = nil,
        preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared),
        schoolsService: SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
        videoLinksService: VideoLinksManaging = VideoLinksServiceImpl(),
        photoService: ProfilePhotoManaging = ProfilePhotoServiceImpl()
    ) {
        self.service = service
        self.authManager = authManager
        self.targetUserId = targetUserId
        self.familyUnitId = familyUnitId
        self.preferenceService = preferenceService
        self.schoolsService = schoolsService
        self.videoLinksService = videoLinksService
        self.photoService = photoService
    }

    private var token: String? { authManager.session?.accessToken }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let loaded = try await service.fetchProfile(accessToken: token) else { return }
            apply(loaded)
        } catch PublicProfileAPIError.unauthorized {
            let refreshed = await retryAfterRefresh {
                try await self.service.fetchProfile(accessToken: self.token)
            }
            if let refreshed, let profile = refreshed {
                apply(profile)
            }
        } catch {
            // leave state as-is; view shows unconfigured/empty
        }
    }

    func save() async {
        saveError = nil
        // Slug validity is independent of the other fields: an invalid/reserved local slug
        // must not block persisting bio/publish/visibility/color. Only the vanity_slug key
        // itself is conditional; when invalid it's omitted so the server keeps the existing slug.
        var slugToSend: String??
        switch SlugValidator.validate(vanitySlug) {
        case .empty, .valid:
            slugError = nil
            slugToSend = .some(vanitySlug.isEmpty ? nil : vanitySlug)
        case .invalidFormat:
            slugError = String(localized: "Use lowercase letters, numbers, and hyphens only.")
            slugToSend = nil
        case .reserved:
            slugError = String(localized: "That custom URL is reserved.")
            slugToSend = nil
        }
        let payload = UpdateProfilePayload(
            bio: .some(bio.isEmpty ? nil : bio),
            isPublished: isPublished,
            showAcademics: showAcademics, showAthletic: showAthletic,
            showFilm: showFilm, showSchools: showSchools,
            headerColor: headerColor.rawValue,
            vanitySlug: slugToSend
        )
        do {
            try await service.updateProfile(payload, accessToken: token)
        } catch PublicProfileAPIError.slugTaken {
            slugError = String(localized: "That custom URL is already taken.")
        } catch PublicProfileAPIError.slugInvalid {
            slugError = String(localized: "That custom URL is invalid or reserved.")
        } catch PublicProfileAPIError.unauthorized {
            await retrySaveAfterRefresh(payload)
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Couldn't save changes. Please try again.")
        }
    }

    /// Retries a failed save once after a token refresh. Unlike a bare `try?`, a slug
    /// conflict or server error on the retry is surfaced to the user rather than dropped.
    private func retrySaveAfterRefresh(_ payload: UpdateProfilePayload) async {
        _ = try? await authManager.refreshSession()
        do {
            try await service.updateProfile(payload, accessToken: token)
        } catch PublicProfileAPIError.slugTaken {
            slugError = String(localized: "That custom URL is already taken.")
        } catch PublicProfileAPIError.slugInvalid {
            slugError = String(localized: "That custom URL is invalid or reserved.")
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Couldn't save changes. Please try again.")
        }
    }

    func validateSlug() {
        switch SlugValidator.validate(vanitySlug) {
        case .empty, .valid: slugError = nil
        case .invalidFormat:
            slugError = String(localized: "Use lowercase letters, numbers, and hyphens only.")
        case .reserved:
            slugError = String(localized: "That custom URL is reserved.")
        }
    }

    /// Built from persisted server truth (`profile`), not the live-editable `vanitySlug` field,
    /// so Copy never hands out a not-yet-accepted slug.
    var shareURL: URL? {
        guard let profile, let base = SupabaseConfig.apiBaseURL else { return nil }
        let persistedSlug = profile.vanitySlug
        let slug = persistedSlug.flatMap { $0.isEmpty ? nil : $0 } ?? profile.hashSlug
        return base.appendingPathComponent("p").appendingPathComponent(slug)
    }

    /// Assembles native card-preview data from existing iOS services, scoped to
    /// `targetUserId` (or the current user) and gated on the VM's live toggle state so the
    /// preview updates immediately when a toggle flips, without waiting for `save()`.
    func assembleCard() async {
        guard let uid = targetUserId ?? authManager.user?.id else {
            cardData = nil
            return
        }

        let isSelf = uid == authManager.user?.id
        let selfName = authManager.user?.fullName

        // Fetched sequentially rather than via concurrent `async let`: the shared,
        // non-Sendable service/mock instances aborted under the CI simulator's
        // stricter concurrency runtime (SIGABRT). Card assembly is a one-off user
        // action, so the small added latency is an acceptable trade for stability.
        let details: PlayerDetails? = try? await preferenceService.fetchPreferences(
            category: .player, userId: uid
        )
        let photoUrl = try? await photoService.currentPhotoURL(userId: uid)
        let videos = (try? await videoLinksService.fetchVideoLinks(userId: uid)) ?? []
        let schools = await fetchSchoolsData()
        // A parent viewing an athlete's card has no self name to use; look it up (RLS-gated).
        let name = (isSelf ? selfName : (try? await photoService.fullName(userId: uid))) ?? ""

        cardData = PublicProfileData(
            playerName: name,
            photoUrl: photoUrl,
            headerColor: headerColor,
            bio: bio.isEmpty ? nil : bio,
            academics: showAcademics ? academicsSection(from: details) : nil,
            athletic: showAthletic ? athleticSection(from: details) : nil,
            film: showFilm ? videos.map { PublicProfileData.FilmItem(title: $0.title, url: $0.url) } : nil,
            schools: showSchools ? schools.map { PublicProfileData.SchoolItem(id: $0.id, name: $0.name) } : nil,
            social: socialSection(from: details)
        )
    }

    private func socialSection(from details: PlayerDetails?) -> PublicProfileData.SocialSection? {
        guard let details else { return nil }
        let section = PublicProfileData.SocialSection(
            twitterHandle: details.twitterHandle,
            instagramHandle: details.instagramHandle,
            tiktokHandle: details.tiktokHandle,
            facebookUrl: details.facebookUrl
        )
        return section.isEmpty ? nil : section
    }

    private func fetchSchoolsData() async -> [School] {
        guard let familyUnitId else { return [] }
        return (try? await schoolsService.fetchSchools(familyUnitId: familyUnitId)) ?? []
    }

    private func academicsSection(from details: PlayerDetails?) -> PublicProfileData.AcademicsSection? {
        guard let details else { return nil }
        return PublicProfileData.AcademicsSection(
            gpa: details.gpa,
            satScore: details.satScore,
            actScore: details.actScore,
            graduationYear: details.graduationYear,
            highSchool: details.highSchool,
            coreCourses: details.coreCourses
        )
    }

    private func athleticSection(from details: PlayerDetails?) -> PublicProfileData.AthleticSection? {
        guard let details else { return nil }
        return PublicProfileData.AthleticSection(
            primarySport: details.primarySport,
            primaryPosition: details.primaryPosition,
            positions: details.positions,
            heightInches: details.heightInches,
            weightLbs: details.weightLbs,
            ncaaId: details.ncaaId,
            perfectGameId: details.perfectGameId,
            prepBaseballId: details.prepBaseballId
        )
    }

    private func apply(_ profile: PlayerProfile) {
        self.profile = profile
        bio = profile.bio ?? ""
        vanitySlug = profile.vanitySlug ?? ""
        isPublished = profile.isPublished
        headerColor = HeaderColor.from(profile.headerColor)
        showAcademics = profile.showAcademics
        showAthletic = profile.showAthletic
        showFilm = profile.showFilm
        showSchools = profile.showSchools
    }

    @discardableResult
    private func retryAfterRefresh<T>(_ op: () async throws -> T) async -> T? {
        do {
            _ = try await authManager.refreshSession()
            return try await op()
        } catch {
            return nil
        }
    }
}
