import Foundation
import SwiftUI
import Observation
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PlayerDetailsViewModel")

@Observable
@MainActor
final class PlayerDetailsViewModel {

    var details: PlayerDetails = .default
    var isLoading = false
    var isUploadingPhoto = false
    var errorMessage: String?
    /// Optimistic local preview of a just-picked image (before/while it uploads).
    var profileImage: UIImage?
    /// Persisted, family-shared photo URL for the athlete (`users.profile_photo_url`).
    var photoUrl: String?
    var isReadOnly = false
    var showDeletePhotoConfirmation = false
    var saveStatus: SaveStatus = .idle
    var hapticSuccessTrigger = 0
    var selectedTab: Int = 0

    /// Whether the athlete has ≥1 highlight video (`video_links` table) — feeds the
    /// canonical completeness score. Fetched on load; defaults false.
    var hasHighlightVideo = false
    /// Whether the athlete's home location is set — feeds the completeness score.
    var hasHomeLocation = false

    // Backward-compat computed wrappers (existing tests use these)
    var isSaving: Bool { saveStatus == .saving }
    var hasUnsavedChanges: Bool { saveStatus == .saving }
    var successMessage: String? { saveStatus == .saved ? "Saved" : nil }

    private let preferenceService: any PreferenceManaging
    private let photoService: any ProfilePhotoManaging
    private let videoLinksService: any VideoLinksManaging
    private let authManager: any AuthManaging
    /// Whose player profile this VM reads/writes. `nil` = the current user's own row.
    /// A parent viewing the family athlete passes the athlete's user id so the whole
    /// family reads and edits the single canonical player row (RLS-gated).
    private let targetUserId: String?

    /// The athlete whose video/location we score: the explicit target, else the
    /// signed-in user (a player viewing their own profile).
    private var effectiveUserId: String? { targetUserId ?? authManager.user?.id }

    /// Canonical athlete id for child editors (e.g. Video Links). Empty when no
    /// user is resolvable yet — the editor treats that as an empty, read-only list.
    var athleteUserId: String { effectiveUserId ?? "" }

    /// Public read accessor so other views (e.g. `PublicTab`) can pass the athlete
    /// context through without exposing write access to `targetUserId`.
    var publicTargetUserId: String? { targetUserId }
    @ObservationIgnored nonisolated(unsafe) private var pendingAutoSave: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

    init(
        preferenceService: any PreferenceManaging,
        userRole: UserRole,
        targetUserId: String? = nil,
        photoService: any ProfilePhotoManaging = ProfilePhotoServiceImpl(),
        videoLinksService: any VideoLinksManaging = VideoLinksServiceImpl(),
        authManager: (any AuthManaging)? = nil
    ) {
        self.preferenceService = preferenceService
        self.photoService = photoService
        self.videoLinksService = videoLinksService
        self.authManager = authManager ?? AuthManager.shared
        self.targetUserId = targetUserId
        // Parents and players collaborate on the same player profile; everyone can edit.
        self.isReadOnly = false
    }

    nonisolated deinit {
        pendingAutoSave?.cancel()
        pendingStatusReset?.cancel()
    }

    // MARK: - Completeness

    var completenessScore: Double {
        details.completenessScore(hasHighlightVideo: hasHighlightVideo, hasHomeLocation: hasHomeLocation)
    }

    var isBaseballOrSoftball: Bool { details.isBaseballOrSoftball }

    // MARK: - Auto-Save

    func scheduleAutoSave() {
        guard !isReadOnly else { return }
        pendingAutoSave?.cancel()
        saveStatus = .saving
        pendingAutoSave = Task {
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            // Unstructured task so cancelling pendingAutoSave (next keystroke)
            // only ever kills the debounce delay, never an in-flight save.
            Task { await self.saveDetails() }
        }
    }

    func markChanged() {
        guard !isReadOnly else { return }
        scheduleAutoSave()
    }

    // MARK: - Load/Save

    func loadDetails() async {
        logger.debug("Loading player details")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let savedDetails: PlayerDetails = try await preferenceService.fetchPreferences(category: .player, userId: targetUserId) {
                details = savedDetails
                normalizePositions()
                seedTravelTeams()
                logger.info("Loaded existing player details")
            } else {
                details = .default
                logger.info("No existing details, using defaults")
            }
            saveStatus = .idle
        } catch {
            logger.error("Failed to load details: \(error.localizedDescription)")
            errorMessage = String(localized: "Failed to load player details. Please try again.")
        }
        await loadPhoto()
        await loadCompletenessInputs()
    }

    /// Fetches the two completeness signals that live outside the player-prefs blob:
    /// a highlight video (`video_links` table) and a set home location. Failures are
    /// non-fatal — the score just treats the signal as absent.
    func loadCompletenessInputs() async {
        do {
            let loc: HomeLocation? = try await preferenceService.fetchPreferences(
                category: .location, userId: targetUserId)
            hasHomeLocation = loc?.isSet ?? false
        } catch {
            logger.error("Failed to load home location for completeness: \(error.localizedDescription)")
            hasHomeLocation = false
        }

        guard let userId = effectiveUserId else {
            hasHighlightVideo = false
            return
        }
        do {
            hasHighlightVideo = try await !videoLinksService.fetchVideoLinks(userId: userId).isEmpty
        } catch {
            logger.error("Failed to load video links for completeness: \(error.localizedDescription)")
            hasHighlightVideo = false
        }
    }

    /// Loads the athlete's persisted, family-shared profile photo URL for display.
    func loadPhoto() async {
        guard let userId = targetUserId else { return }
        do {
            photoUrl = try await photoService.currentPhotoURL(userId: userId)
        } catch {
            logger.error("Failed to load profile photo: \(error.localizedDescription)")
        }
    }

    func saveDetails() async {
        guard !isReadOnly else { return }
        logger.debug("Saving player details")
        saveStatus = .saving
        normalizePositions()
        pruneAndMirrorTravelTeams()
        do {
            _ = try await preferenceService.savePreferences(category: .player, userId: targetUserId, data: details)
            saveStatus = .saved
            hapticSuccessTrigger += 1
            logger.info("Player details saved")
            pendingStatusReset?.cancel()
            pendingStatusReset = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if self.saveStatus == .saved { self.saveStatus = .idle }
            }
        } catch {
            logger.error("Failed to save details: \(error.localizedDescription)")
            errorMessage = String(localized: "Failed to save player details. Please try again.")
            saveStatus = .idle
        }
    }

    func triggerFitScoreRecalculation() {
        Task {
            logger.info("Fit score recalculation triggered (stub — wire to API when available)")
        }
    }

    // MARK: - Photo Upload

    func uploadProfilePhoto(_ image: UIImage) async {
        guard !isReadOnly, let userId = targetUserId else { return }
        logger.debug("Uploading profile photo")
        isUploadingPhoto = true
        errorMessage = nil
        defer { isUploadingPhoto = false }
        do {
            profileImage = image  // optimistic preview while the upload runs
            let url = try await photoService.upload(image: image, userId: userId)
            photoUrl = url
            logger.info("Profile photo uploaded successfully")
        } catch {
            profileImage = nil
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            errorMessage = String(localized: "Failed to upload photo. Please try again.")
        }
    }

    func deleteProfilePhoto() async {
        guard !isReadOnly, let userId = targetUserId else { return }
        do {
            try await photoService.delete(userId: userId, currentPhotoURL: photoUrl ?? "")
            profileImage = nil
            photoUrl = nil
            logger.info("Profile photo deleted")
        } catch {
            logger.error("Failed to delete photo: \(error.localizedDescription)")
            errorMessage = String(localized: "Failed to remove photo. Please try again.")
        }
    }

    // MARK: - Field Updates

    func updateGraduationYear(_ value: Int?) {
        details.graduationYear = value
        markChanged()
    }

    func updateGPA(_ value: Double?) {
        if let gpa = value, gpa >= 0.0 && gpa <= 5.0 {
            details.gpa = gpa
            markChanged()
        } else if value == nil {
            details.gpa = nil
            markChanged()
        }
    }

    func updateSAT(_ value: Int?) {
        if let sat = value, sat >= 400 && sat <= 1600 {
            details.satScore = sat
            markChanged()
        } else if value == nil {
            details.satScore = nil
            markChanged()
        }
    }

    func updateACT(_ value: Int?) {
        if let act = value, act >= 1 && act <= 36 {
            details.actScore = act
            markChanged()
        } else if value == nil {
            details.actScore = nil
            markChanged()
        }
    }

    func updateHeight(feet: Int, inches: Int) {
        details.heightInches = (feet * 12) + inches
        markChanged()
    }

    /// Snap stored positions to the canonical, sport-scoped vocabulary (expands
    /// abbreviations, preserves unknowns; vague catch-alls no longer resolve).
    /// `positions` is the ordered source of truth (index 0 = primary), so mirror
    /// `positions[0]` back onto the legacy `primaryPosition` string — this keeps
    /// every downstream reader (template resolver, completeness, public profile)
    /// in sync and matches web. Runs on load and before save.
    func normalizePositions() {
        let sport = details.primarySport
        let normalized = details.positions?.compactMap {
            CanonicalPositions.normalize(sport: sport, $0)
        }
        details.positions = normalized
        details.primaryPosition =
            normalized?.first
            ?? CanonicalPositions.normalize(sport: sport, details.primaryPosition)
    }

    /// Reorder the selected positions — index 0 is the athlete's primary, index 1
    /// their secondary. Marks the form dirty so the change autosaves.
    func movePosition(_ index: Int, _ direction: MoveDirection) {
        guard var list = details.positions else { return }
        let target = direction == .up ? index - 1 : index + 1
        guard index >= 0, index < list.count, target >= 0, target < list.count else { return }
        list.swapAt(index, target)
        details.positions = list
        markChanged()
    }

    enum MoveDirection { case up, down }

    // MARK: - Travel Teams

    /// Whether a travel-team row carries any user data (mirrors web's blank filter).
    private func isNonEmpty(_ team: TravelTeam) -> Bool {
        team.year != nil
            || !(team.name ?? "").isEmpty
            || !(team.coach ?? "").isEmpty
    }

    /// On load, seed the repeatable list from the legacy scalars the first time an
    /// athlete opens the new UI (no `travel_teams` stored yet). Mirrors web
    /// `buildLegacyTravelTeam`: if all three scalars are empty, the list stays empty.
    private func seedTravelTeams() {
        if let existing = details.travelTeams, !existing.isEmpty { return }
        if details.travelTeamYear == nil
            && (details.travelTeamName ?? "").isEmpty
            && (details.travelTeamCoach ?? "").isEmpty {
            details.travelTeams = []
            return
        }
        details.travelTeams = [
            TravelTeam(
                year: details.travelTeamYear,
                name: details.travelTeamName ?? "",
                coach: details.travelTeamCoach ?? ""
            )
        ]
    }

    /// Before save: drop fully-blank rows, sort by year descending, and mirror the
    /// most-recent surviving row back onto the legacy scalar fields so downstream
    /// readers (edit-history labels, coach-outreach template resolver) keep working.
    private func pruneAndMirrorTravelTeams() {
        let surviving = (details.travelTeams ?? [])
            .filter(isNonEmpty)
            .sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        details.travelTeams = surviving
        let latest = surviving.first
        details.travelTeamYear = latest?.year
        details.travelTeamName = latest?.name ?? ""
        details.travelTeamCoach = latest?.coach ?? ""
    }

    /// Appends a blank row. Deliberately does NOT autosave — an immediate save
    /// would prune the empty row before the user types (matches web `addTravelTeam`).
    func addTravelTeam() {
        guard !isReadOnly else { return }
        details.travelTeams = (details.travelTeams ?? []) + [TravelTeam(year: nil, name: "", coach: "")]
    }

    func removeTravelTeam(at index: Int) {
        guard !isReadOnly, var teams = details.travelTeams, teams.indices.contains(index) else { return }
        teams.remove(at: index)
        details.travelTeams = teams
        markChanged()
    }

    // MARK: - Computed

    var heightFeet: Int { (details.heightInches ?? 0) / 12 }
    var heightInchesRemainder: Int { (details.heightInches ?? 0) % 12 }
}
