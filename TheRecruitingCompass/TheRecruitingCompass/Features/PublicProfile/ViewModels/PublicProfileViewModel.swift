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
        slugError = nil
        validateSlug()
        if slugError != nil { return }
        let payload = UpdateProfilePayload(
            bio: .some(bio.isEmpty ? nil : bio),
            isPublished: isPublished,
            showAcademics: showAcademics, showAthletic: showAthletic,
            showFilm: showFilm, showSchools: showSchools,
            headerColor: headerColor.rawValue,
            vanitySlug: .some(vanitySlug.isEmpty ? nil : vanitySlug)
        )
        do {
            try await service.updateProfile(payload, accessToken: token)
        } catch PublicProfileAPIError.slugTaken {
            slugError = String(localized: "That custom URL is already taken.")
        } catch PublicProfileAPIError.slugInvalid {
            slugError = String(localized: "That custom URL is invalid or reserved.")
        } catch PublicProfileAPIError.unauthorized {
            _ = try? await authManager.refreshSession()
            try? await service.updateProfile(payload, accessToken: token)
        } catch {
            // transient; keep local state
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

    var shareURL: URL? {
        guard let profile, let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = vanitySlug.isEmpty ? profile.hashSlug : vanitySlug
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

        async let detailsTask: PlayerDetails? = try? preferenceService.fetchPreferences(
            category: .player, userId: uid
        )
        async let photoTask: String? = try? photoService.currentPhotoURL(userId: uid)
        async let filmTask: [VideoLink] = (try? videoLinksService.fetchVideoLinks(userId: uid)) ?? []
        async let schoolsTask: [School] = fetchSchoolsData()

        let details = await detailsTask
        let photoUrl = await photoTask
        let videos = await filmTask
        let schools = await schoolsTask

        // Best-effort only: no extra users-table lookup for a non-self targetUserId in this task.
        let name = uid == authManager.user?.id ? (authManager.user?.fullName ?? "") : ""

        cardData = PublicProfileData(
            playerName: name,
            photoUrl: photoUrl,
            headerColor: headerColor,
            bio: bio.isEmpty ? nil : bio,
            academics: showAcademics ? academicsSection(from: details) : nil,
            athletic: showAthletic ? athleticSection(from: details) : nil,
            film: showFilm ? videos.map { PublicProfileData.FilmItem(title: $0.title, url: $0.url) } : nil,
            schools: showSchools ? schools.map { PublicProfileData.SchoolItem(id: $0.id, name: $0.name) } : nil
        )
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

    private func apply(_ p: PlayerProfile) {
        profile = p
        bio = p.bio ?? ""
        vanitySlug = p.vanitySlug ?? ""
        isPublished = p.isPublished
        headerColor = HeaderColor.from(p.headerColor)
        showAcademics = p.showAcademics
        showAthletic = p.showAthletic
        showFilm = p.showFilm
        showSchools = p.showSchools
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
