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
    private let performanceService: PerformanceManaging

    var profile: PlayerProfile?
    var bio: String = ""
    var vanitySlug: String = ""
    var isPublished: Bool = false
    var headerColor: HeaderColor = .slate
    var lookingFor: String = ""
    var valuesTags: [String] = []
    var awards: [ProfileAward] = []
    var commitmentStatus: CommitmentStatus = .uncommitted
    var committedSchoolId: String?
    /// Ordered section rows for the Section Configuration editor. Order in
    /// this array IS the display/save order (parity with web `section_config`).
    var sections: [ProfileSection] = DefaultSectionOrder.keys.map { ProfileSection(key: $0, visible: true) }
    var availableSchools: [School] = []
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
        photoService: ProfilePhotoManaging = ProfilePhotoServiceImpl(),
        performanceService: PerformanceManaging = PerformanceServiceImpl(supabaseManager: .shared)
    ) {
        self.service = service
        self.authManager = authManager
        self.targetUserId = targetUserId
        self.familyUnitId = familyUnitId
        self.preferenceService = preferenceService
        self.schoolsService = schoolsService
        self.videoLinksService = videoLinksService
        self.photoService = photoService
        self.performanceService = performanceService
    }

    private var token: String? { authManager.session?.accessToken }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        availableSchools = await fetchSchoolsData()
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
        // must not block persisting the rest. Only the vanity_slug key itself is conditional;
        // when invalid it's omitted so the server keeps the existing slug.
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
        let payload = buildPayload(slugToSend: slugToSend)
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

    private func buildPayload(slugToSend: String??) -> UpdateProfilePayload {
        UpdateProfilePayload(
            bio: .some(bio.isEmpty ? nil : bio),
            isPublished: isPublished,
            headerColor: headerColor.rawValue,
            vanitySlug: slugToSend,
            lookingFor: .some(lookingFor.isEmpty ? nil : lookingFor),
            valuesTags: valuesTags,
            awards: awards,
            commitmentStatus: commitmentStatus,
            committedSchoolId: .some(commitmentStatus == .committed ? committedSchoolId : nil),
            sectionConfig: sections
        )
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

    // MARK: - Section Configuration (reorder + eye toggle)

    func isSectionVisible(_ key: ProfileSectionKey) -> Bool {
        sections.first { $0.key == key }?.visible ?? false
    }

    func toggleSectionVisibility(_ key: ProfileSectionKey) {
        guard let index = sections.firstIndex(where: { $0.key == key }) else { return }
        sections[index].visible.toggle()
    }

    /// Manual reimplementation of `Array.move(fromOffsets:toOffset:)` (a SwiftUI
    /// extension) so this file stays SwiftUI-free — the ViewModel layer imports
    /// only `Foundation`/`Observation`.
    func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { sections[$0] }
        for index in source.sorted(by: >) { sections.remove(at: index) }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        sections.insert(contentsOf: moving, at: min(max(adjustedDestination, 0), sections.count))
    }

    // MARK: - Values tags (max 12, ≤60 chars)

    func addValueTag(_ raw: String) {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !trimmed.isEmpty, valuesTags.count < 12, !valuesTags.contains(trimmed) else { return }
        valuesTags.append(trimmed)
    }

    func removeValueTag(_ tag: String) {
        valuesTags.removeAll { $0 == tag }
    }

    // MARK: - Awards

    func addAward(title: String, year: Int?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        awards.append(ProfileAward(title: String(trimmed.prefix(120)), year: year))
    }

    func removeAward(_ award: ProfileAward) {
        awards.removeAll { $0.id == award.id }
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
    /// `targetUserId` (or the current user) and gated on the VM's live section
    /// visibility state so the preview updates immediately when a toggle/reorder
    /// flips, without waiting for `save()`.
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
        let metricRows = (try? await performanceService.fetchMetrics(userId: uid)) ?? []
        // A parent viewing an athlete's card has no self name to use; look it up (RLS-gated).
        let name = (isSelf ? selfName : (try? await photoService.fullName(userId: uid))) ?? ""

        cardData = PublicProfileData(
            playerName: name,
            photoUrl: photoUrl,
            headerColor: headerColor,
            bio: bio.isEmpty ? nil : bio,
            academics: isSectionVisible(.academics) ? academicsSection(from: details) : nil,
            credentials: credentialsRow(from: details),
            metrics: isSectionVisible(.metrics) ? Self.buildMetrics(from: metricRows) : nil,
            film: isSectionVisible(.film) ? videos.map { PublicProfileData.FilmItem(title: $0.title, url: $0.url) } : nil,
            lookingFor: isSectionVisible(.values) ? (lookingFor.isEmpty ? nil : lookingFor) : nil,
            valuesTags: isSectionVisible(.values) ? valuesTags : [],
            teamHistory: isSectionVisible(.teamHistory) ? Self.buildTeamHistory(from: details) : nil,
            awards: isSectionVisible(.awards) ? awards.map { PublicProfileData.AwardEntry(title: $0.title, year: $0.year) } : nil,
            social: socialSection(from: details),
            commitmentStatus: commitmentStatus,
            committedSchoolName: committedSchoolId.flatMap { id in availableSchools.first { $0.id == id }?.name },
            updatedAt: profile.flatMap { PublicProfileViewModel.parseDate($0.updatedAt) },
            visibleSectionOrder: sections.filter(\.visible).map(\.key)
        )
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    /// One card per `metric_type` (newest by `created_at` wins), ranked
    /// primary+verified first, capped at 6 — byte-parity with web
    /// `buildPublicMetrics`. Value/unit come from `MetricType`/`MetricRegistry`,
    /// never the stored row's `unit`/`display_value`.
    static func buildMetrics(from rows: [PerformanceMetric]) -> [PublicProfileData.MetricEntry] {
        var newestByType: [String: PerformanceMetric] = [:]
        for row in rows {
            if let prev = newestByType[row.metricType.rawValue], prev.createdAt >= row.createdAt { continue }
            newestByType[row.metricType.rawValue] = row
        }
        func rank(_ r: PerformanceMetric) -> Int { (r.isPrimary ? 0 : 10) + (r.verified ? 0 : 1) }
        return newestByType.values
            .sorted { rank($0) < rank($1) }
            .prefix(6)
            .map { row in
                PublicProfileData.MetricEntry(
                    key: row.metricType.rawValue,
                    label: row.metricType.displayName,
                    value: row.metricType.format(row.value),
                    unit: row.metricType.defaultUnit,
                    verified: row.verified
                )
            }
    }

    /// Grade-level HS teams + travel/club teams, in that order — byte-parity
    /// with web `buildTeamHistory`. `contact` is always nil today: no
    /// reference-phone field exists on either platform yet.
    static func buildTeamHistory(from details: PlayerDetails?) -> [PublicProfileData.TeamHistoryEntry] {
        guard let details else { return [] }
        var out: [PublicProfileData.TeamHistoryEntry] = []
        let gradeFields: [(String?, String?, String)] = [
            (details.twelfthGradeTeam, details.twelfthGradeCoach, String(localized: "12th Grade")),
            (details.eleventhGradeTeam, details.eleventhGradeCoach, String(localized: "11th Grade")),
            (details.tenthGradeTeam, details.tenthGradeCoach, String(localized: "10th Grade")),
            (details.ninthGradeTeam, details.ninthGradeCoach, String(localized: "9th Grade"))
        ]
        for (name, coach, level) in gradeFields {
            let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !trimmed.isEmpty else { continue }
            out.append(.init(name: trimmed, level: level, coach: coach, contact: nil, years: nil))
        }
        for team in details.travelTeams ?? [] {
            let trimmed = team.name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !trimmed.isEmpty else { continue }
            out.append(.init(
                name: trimmed, level: String(localized: "Travel"), coach: team.coach,
                contact: nil, years: team.year.map(String.init)
            ))
        }
        return out
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
            intendedMajor: details.intendedMajor,
            coreCourses: details.coreCourses
        )
    }

    private func credentialsRow(from details: PlayerDetails?) -> PublicProfileData.CredentialsRow? {
        guard let details else { return nil }
        return PublicProfileData.CredentialsRow(
            primarySport: details.primarySport,
            primaryPosition: details.primaryPosition,
            positions: details.positions,
            heightInches: details.heightInches,
            weightLbs: details.weightLbs,
            ncaaId: details.ncaaId,
            perfectGameId: details.perfectGameId,
            prepBaseballId: details.prepBaseballId,
            prepBaseballState: details.prepBaseballState,
            athleticNetId: details.athleticNetId,
            milesplitUrl: details.milesplitUrl,
            swimcloudId: details.swimcloudId,
            utrId: details.utrId,
            tennisRecruitingId: details.tennisRecruitingId,
            eliteProspectsId: details.eliteProspectsId,
            sportsrecruitsId: details.sportsrecruitsId,
            concept2Id: details.concept2Id,
            on3Url: details.on3Url,
            sports247Url: details.sports247Url
        )
    }

    private func apply(_ profile: PlayerProfile) {
        self.profile = profile
        bio = profile.bio ?? ""
        vanitySlug = profile.vanitySlug ?? ""
        isPublished = profile.isPublished
        headerColor = HeaderColor.from(profile.headerColor)
        lookingFor = profile.lookingFor ?? ""
        valuesTags = profile.valuesTags
        awards = profile.awards
        commitmentStatus = profile.commitmentStatus
        committedSchoolId = profile.committedSchoolId
        sections = profile.sectionConfig
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
